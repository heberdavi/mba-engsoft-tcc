# Análise Crítica e Documentação Técnica do Pipeline de PLN
### Do TCC à publicação em congresso — evolução do pipeline de identificação de âncoras emocionais em textos bíblicos (MBA Engenharia de Software — USP/ESALQ)
**Artefatos avaliados:** `01-processamento_pln.ipynb` (Google Colab) + `01-schema.sql` (SQLite)
**Contexto desta versão:** o TCC já foi entregue (sem RAG). Esta análise cobre a fase de evolução do trabalho — pipeline com RAG, ainda em PoC restrita ao livro de Jó (`livro_id = 18`), mas com objetivo declarado de (a) escalar para todo o corpus bíblico e (b) ser submetido a congressos/eventos de PLN. As recomendações abaixo priorizam o que fortalece o trabalho como contribuição científica, não apenas como engenharia de PoC.

---

## 1. Visão Geral da Arquitetura

O pipeline é um notebook monolítico do Google Colab organizado em 7 células sequenciais, com estado persistido em SQLite (montado via Google Drive) e uma base vetorial ChromaDB usada em uma etapa específica de RAG. O fluxo lógico é:

| Célula | Responsabilidade | Entrada | Saída |
|---|---|---|---|
| 1 | Monta o Drive e define caminhos | — | Variáveis de path |
| 2 | Instala dependências e aplica o schema | `01-schema.sql` | Estrutura de tabelas no `.db` |
| 3 | Carga inicial (seed) idempotente | `02-seed_data.sql` | Tabela `verso` populada |
| 4 | Limpeza estrutural + filtro de densidade gramatical (spaCy) | `verso.texto` | `verso_limpo.texto_limpo` |
| 5 | Classificação Zero-Shot por eixos existenciais (BERTopic + BERTimbau) | `verso_limpo` | `verso_topico` (probabilidades, entropia, margem) |
| 5.1 | Arbitragem via RAG híbrido (ChromaDB + Gemini) para casos de alta ambiguidade | `verso_topico` (entropia > 0.80) | Atualização de `verso_topico` + `rag_auditoria` |
| 6 | Análise de sentimento (pysentimiento/BERTimbau) e cruzamento com os eixos | `verso.texto` | `verso_sentimento` + resumo executivo |

O desenho geral segue uma arquitetura em **camadas de enriquecimento incremental** sobre o mesmo conjunto de versículos — cada célula adiciona uma tabela nova ou complementa uma existente, o que é coerente com o schema relacional apresentado (`verso` → `verso_limpo` → `verso_topico` → `rag_auditoria` / `verso_sentimento`).

---

## 2. Stack Tecnológico e Conceitos Adotados

| Camada | Tecnologia | Papel no pipeline |
|---|---|---|
| Ambiente de execução | Google Colab + Google Drive | Runtime efêmero com GPU opcional; persistência externa via Drive |
| Persistência relacional | SQLite | Fonte de verdade estruturada (texto, metadados, resultados) |
| Persistência vetorial | ChromaDB (`PersistentClient`) | Índice de embeddings dos comentários exegéticos (Moody) para RAG |
| PLN estrutural | spaCy (`pt_core_news_lg`) | POS tagging para filtro de ruído nominal/estrutural |
| Modelagem de tópicos | BERTopic (modo *zero-shot*) | Classificação dos versículos nos 4 eixos existenciais sem necessidade de dataset rotulado |
| Embeddings (tópicos) | `transformers.pipeline("feature-extraction", model="neuralmind/bert-base-portuguese-cased")` | Vectoriza os documentos para o BERTopic |
| Embeddings (RAG) | `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | Vetoriza consultas para busca no ChromaDB |
| LLM de arbitragem | Google Gemini (`gemini-3.6-flash`) via `google-genai` | Reclassifica casos de alta entropia com contexto recuperado (RAG) |
| Análise de sentimento | pysentimiento (BERTimbau) | Classifica polaridade (POS/NEU/NEG) por versículo |
| Métricas de incerteza (XAI) | Entropia de Shannon, margem de dominância, gap de confiança | Fundamenta decisões de classificação e aciona o RAG seletivamente |

---

## 3. Regras de Negócio Implementadas

1. **Filtro de ruído estrutural (Célula 4):** versículos com poucos tokens significativos e alta razão de nomes próprios (ex.: listas genealógicas) são marcados como `RUIDO_NOMINAL`/`RUIDO_VAZIO`/`RUIDO_CURTO` e desviados do Transformer, economizando processamento.
2. **Janelamento textual (Célula 5):** o texto usado para embutir cada versículo é a concatenação do anterior + atual + posterior (no texto **original**, não no limpo), preservando conectivos para o mecanismo de atenção do BERTimbau.
3. **Cascata de decisão por gênero literário (Célula 5):** os limiares de `best_score` e `margem_dominancia` mudam conforme o `genero_id` (Pentateuco/Histórico exige rigor máximo; Poético/Profético aceita menor confiança; Evangelhos/Epístolas têm regra de "resgate").
4. **Ativação seletiva do RAG (Célula 5.1):** somente versículos com `entropia > 0.80` são reprocessados via ChromaDB + Gemini — uma estratégia de *human-in-the-loop* substituída por *LLM-in-the-loop* apenas nos casos ambíguos.
5. **Retriever híbrido (Célula 5.1):** busca vetorial no ChromaDB é restringida por um filtro estrutural (`where`) que exige que o capítulo/versículo da consulta esteja dentro do intervalo do chunk de comentário, evitando que trechos de outros capítulos "vazem" para o contexto.
6. **Auditoria/XAI (Célula 5.1):** toda reclassificação via RAG grava o tópico anterior, o novo tópico, a justificativa textual do LLM, o `chunk_id` usado e o score de similaridade — rastreabilidade completa da decisão.

---

## 4. Pontos Fortes

### 4.1 Idempotência na carga de dados (Célula 3)
A checagem `SELECT count(*) FROM verso` antes de rodar o seed evita duplicação de dados ao reexecutar o notebook em sessões diferentes do Colab. Isso é essencial num ambiente de runtime efêmero, onde reexecuções acidentais são comuns — sem essa guarda, cada nova sessão dobraria o corpus.

### 4.2 Deleção seletiva por livro (Células 4 e 5)
Em vez de truncar as tabelas inteiras, o pipeline apaga apenas os registros do livro em processamento (`WHERE livro_id = 18`) antes de reinserir. Isso é forte porque **prepara o pipeline para escalar** para os demais livros da Bíblia sem destruir o que já foi processado — um detalhe de engenharia que muitos PoCs acadêmicos negligenciam.

### 4.3 Zero-Shot Topic Modeling com âncoras semânticas de domínio
Usar `zeroshot_topic_list` com descrições ricas (não apenas rótulos de uma palavra) para os 4 eixos existenciais é uma escolha metodologicamente sólida: evita a necessidade de um dataset rotulado (que não existe para "âncoras emocionais bíblicas") e ancora a classificação em conceitos teóricos citáveis no trabalho (Han, Bauman, Frankl).

### 4.4 Quantificação de incerteza como sinal de engenharia, não só de análise
O cálculo de entropia, margem de dominância e gap de confiança não é usado apenas para relatar resultados — ele **decide o que acontece a seguir** (acionar ou não o RAG). Isso transforma uma métrica estatística passiva em um mecanismo de controle de custo/qualidade, o que é elegante e economiza chamadas caras ao LLM.

### 4.5 Retriever híbrido (estrutural + semântico)
Combinar um filtro de metadados (intervalo de capítulo/versículo) com busca vetorial reduz o risco clássico de RAG "genérico" trazer um trecho de comentário sobre um capítulo errado só porque o embedding é semanticamente parecido. Isso é uma boa prática de RAG contextual, não um RAG ingênuo.

### 4.6 Trilha de auditoria e explicabilidade (tabela `rag_auditoria`)
Registrar `topico_id_anterior`, `topico_id_novo`, `justificativa`, `chunk_id` e `score_similaridade` para cada arbitragem via LLM é um ponto forte raro em projetos acadêmicos com RAG: permite auditar *por que* o modelo mudou de opinião em cada caso — essencial para um artigo de PLN que queira discutir explicabilidade como contribuição.

### 4.7 Retry com backoff para limites de cota
O tratamento de `429`/`RESOURCE_EXHAUSTED`/`503` com espera crescente (`25 * (tentativa + 1)`) mostra consciência de que se está operando sob um free tier com RPM/RPD restritos — sem isso, o processamento pararia na primeira flutuação de cota.

### 4.8 Saída estruturada forçada (`response_mime_type: application/json`)
Exigir JSON estruturado do Gemini, em vez de fazer parsing de texto livre, é a prática correta para confiabilidade em pipelines com LLMs — elimina uma classe inteira de erros de parsing.

### 4.9 Persistência de probabilidades brutas por eixo
Guardar `p_exaustao`, `p_transitoriedade`, `p_vazio`, `p_narrativo` (não só o rótulo final) permite reanálises futuras (recalibrar limiares, gerar novas métricas) sem precisar reprocessar o modelo. (Ver §7 para uma crítica ao *formato* dessa persistência.)

---

## 5. Pontos Fracos e Propostas de Intervenção

### 5.1 Inconsistência de espaço vetorial entre as etapas de embeddings
**Problema:** a Célula 5 gera embeddings via `pipeline("feature-extraction", model="neuralmind/bert-base-portuguese-cased")` (BERTimbau puro, 768 dimensões), enquanto a Célula 5.1 usa `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` (384 dimensões) para consultar o ChromaDB. São dois modelos, dois espaços semânticos e duas dimensionalidades diferentes coexistindo no mesmo pipeline, sem nenhuma relação matemática entre eles. O `feature-extraction` pipeline retorna, por padrão, os *hidden states por token*, não um vetor único de sentença — e o BERTimbau cru não foi treinado para similaridade semântica (é um MLM, não um Sentence-BERT).

**Intervenção proposta:** unificar o modelo de embeddings em um único Sentence-Transformer treinado para similaridade em português, usado tanto no BERTopic quanto no ChromaDB — por exemplo, `rufimelo/bert-large-portuguese-cased-sts` (especializado em STS-PT) em vez do MiniLM multilíngue genérico. Ganho: consistência matemática, comparabilidade direta entre versículo e chunk de comentário, e uma escolha de modelo defensável na avaliação por pares.

### 5.2 Uso do BERTopic para uma tarefa que é, na prática, classificação por similaridade de cosseno
**Problema:** a variável `topics` retornada por `fit_transform` nunca é usada — toda a lógica de decisão é reconstruída manualmente a partir de `probs_matrix`. Isso sugere que o BERTopic completo (UMAP + HDBSCAN + c-TF-IDF por baixo dos panos) está sendo usado apenas como gerador de similaridade a 4 âncoras.

**Intervenção proposta:** substituir por classificação zero-shot explícita — cosseno direto entre embeddings (mais simples e auditável) ou um pipeline `zero-shot-classification` via NLI multilíngue (ex.: `MoritzLaurer/mDeBERTa-v3-base-mnli-xnli`), desenhado especificamente para esse tipo de tarefa. Se o objetivo do artigo for justamente comparar abordagens (BERTopic zero-shot vs. NLI zero-shot vs. cosseno puro), isso pode virar uma seção de experimentos comparativos — um ângulo genuinamente publicável.

### 5.3 Limiares de decisão hardcoded sem validação estatística
**Problema:** os limiares por gênero (`0.88`/`0.15`, `0.50`, `0.60`/`0.45`/`0.10`, `0.75`) parecem calibrados por inspeção manual do livro de Jó, sem matriz de confusão, precisão/revocação ou curva ROC.

**Intervenção proposta:** construir um *gold standard* rotulado por consenso (mínimo 50–100 versículos por gênero literário), calcular métricas por eixo/gênero, e substituir a cascata de `if/elif` por um classificador leve (regressão logística sobre `[best_score, margem, entropia, genero_id, tamanho_texto]`) ou por calibração de probabilidade (Platt/temperature scaling). Para um artigo de congresso, essa validação **não é opcional** — é o tipo de evidência que revisores de PLN vão pedir explicitamente antes de aceitar qualquer alegação de acurácia do método.

### 5.4 Critério de ativação do RAG usa apenas entropia, ignorando os outros sinais já calculados
**Problema:** a query da Célula 5.1 filtra somente por `entropia > 0.80`, ignorando `margem_dominancia` e `gap_confianca`, já calculados na Célula 5.

**Intervenção proposta:** compor um score de incerteza combinado (ex.: `incerteza = 0.5*entropia_normalizada + 0.3*(1 - margem) + 0.2*(1 - gap)`) ou usar uma condição `OR` entre os três critérios, validando empiricamente contra o gold standard da seção 5.3.

### 5.5 Pipeline não parametrizado: `livro_id = 18` hardcoded em 3 células
**Problema:** o valor de Jó está fixado em múltiplas queries SQL (Células 4, 5, 6), dificultando a expansão para o corpus completo.

**Intervenção proposta:** extrair `LIVRO_ID_ALVO` como variável de configuração, transformar as células em funções parametrizadas por `livro_id`, e iterar sobre uma lista de livros. Ver também §8, que aprofunda os riscos *conceituais* (não só de engenharia) dessa expansão.

### 5.6 `device=0` hardcoded na Célula 5, ignorando a variável `device` já calculada na Célula 2
**Problema:** se o notebook rodar sem GPU (comum no Colab gratuito), essa linha lança exceção e interrompe todo o processamento do livro.

**Intervenção proposta:** reutilizar a variável `device` da Célula 2 (`device=device`) e logar explicitamente quando o processamento cair para CPU.

### 5.7 Tratamento de exceções amplo demais (`except:` genérico)
**Problema:** ocorre no carregamento do spaCy (Célula 4) e na consulta ao ChromaDB (Célula 5.1), onde qualquer erro no filtro estrutural faz o código recair silenciosamente para busca sem filtro, mascarando bugs reais.

**Intervenção proposta:** capturar exceções específicas e registrar em log sempre que o fallback for acionado, incluindo o `verso_id` afetado.

### 5.8 Ausência de transação atômica entre `DELETE` e `INSERT`
**Problema:** `DELETE` seletivo seguido de `to_sql(append)` sem bloco transacional explícito — uma interrupção no meio deixa o banco inconsistente.

**Intervenção proposta:** usar `with conn:` (commit automático/rollback em exceção) para garantir atomicidade por livro processado.

### 5.9 Dependências sem versão fixada
**Problema:** `!pip install -q ...` sem pinos de versão compromete a reprodutibilidade exigida em publicações científicas.

**Intervenção proposta:** fixar versões exatas em `requirements.txt` versionado no repositório, e citá-las na seção de metodologia do artigo.

### 5.10 Nome do modelo Gemini não corresponde a nenhuma versão publicamente documentada
**Problema:** `model='gemini-3.6-flash'` não corresponde a nenhum identificador que encontrei na documentação atual (os modelos gratuitos documentados em 2026 são `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.0-flash`, e em preview `gemini-3-flash`/`gemini-3.1-flash-lite`).

**Intervenção proposta:** validar o identificador exato na documentação oficial e implementar uma lista de fallback entre modelos, tornando o pipeline resiliente a mudanças de nomenclatura da Google.

---

## 6. Aprofundamento — Os Eixos Conceituais Estão "Hard Coded" em Múltiplos Pontos (e Isso É um Risco Real)

Este é provavelmente o ponto mais importante para a evolução do trabalho rumo a uma publicação, porque afeta diretamente a **defensabilidade teórica** do método, não apenas a qualidade do código.

### 6.1 Mapeamento de todas as fontes de verdade encontradas

Ao ler o notebook com atenção, os 4 eixos existenciais (Exaustão/Refrigério, Transitoriedade/Solidez, Vazio/Propósito, Narrativo/Normativo) aparecem descritos **de forma independente em pelo menos três lugares diferentes**, cada um com uma redação própria:

1. **`descricoes_eixos` (Célula 5):** descrições longas e ricas em imagens específicas de Jó ("o peso da existência... choro nas cinzas, feridas, gemidos, tempestade, o abismo..."), usadas como âncoras semânticas para o `zeroshot_topic_list` do BERTopic.
2. **`mapa_eixos` (Célula 5, inserido na tabela `topico`):** rótulos curtos ("Exaustão vs. Refrigério", "Transitoriedade vs. Solidez" etc.), persistidos como `antidoto_referencia` — uma **terceira redação**, mais compacta, dos mesmos conceitos.
3. **O prompt de arbitragem do Gemini (Célula 5.1):** uma descrição de novo redigida, mais condensada ainda ("0: Exaustão vs. Refrigério (Fadiga existencial, dor física/mental, lamento nas cinzas, busca por descanso)"), com ênfases um pouco diferentes das duas anteriores (por exemplo, "lamento nas cinzas" aparece aqui, mas a "tempestade" e o "abismo" da descrição 1 não aparecem no prompt).

**Por que isso é um problema sério, e não apenas um detalhe de estilo de código:**

- **Risco de deriva semântica silenciosa (*semantic drift*):** se você (ou um coautor) decidir refinar a definição teórica de um eixo — por exemplo, ajustar a fronteira conceitual entre "Vazio/Propósito" (Bauman) e "Transitoriedade/Solidez" para a revisão de um artigo — é preciso lembrar de editar em três lugares fisicamente distantes no notebook. É extremamente fácil atualizar a descrição 1 (BERTopic) e esquecer de atualizar a 3 (prompt do Gemini), fazendo com que o classificador zero-shot e o "juiz" de arbitragem (Gemini) estejam, sem que ninguém perceba, operando sobre **definições teóricas ligeiramente diferentes do mesmo conceito**. Isso é particularmente grave porque a arbitragem via RAG existe justamente para os casos mais ambíguos — exatamente onde uma pequena diferença de definição entre os dois modelos mais importa.
- **Não há registro de autoria/versão da definição teórica em si.** O framework (Han, Bauman, Frankl) é o núcleo intelectual do trabalho, mas não existe, em nenhum lugar do código ou do schema, um "documento único" que diga "esta é a definição canônica do eixo X, versão Y, usada nesta execução do pipeline". Para um artigo científico, isso é uma lacuna de rastreabilidade: se os revisores pedirem para reproduzir o experimento, não há como garantir que a mesma definição textual foi usada em todas as etapas.
- **Dificulta a evolução planejada para o corpus completo.** Como veremos no §8, é provável que as âncoras precisem de ajuste fino por gênero literário para generalizar além de Jó. Com três cópias divergentes do mesmo conceito, qualquer ajuste desse tipo multiplica o esforço e o risco de inconsistência por três.

### 6.2 Intervenção proposta — Framework teórico como dado, não como string espalhada no código

A recomendação central é **elevar os eixos conceituais a uma entidade de primeira classe no modelo de dados** (e não apenas a uma lista Python), com uma única fonte de verdade da qual todas as três representações (âncora do BERTopic, rótulo curto, descrição para o prompt do LLM) são derivadas ou, no mínimo, versionadas em conjunto.

Duas formas concretas de implementar isso, em ordem crescente de rigor:

**Opção A — Config versionado (mais simples, bom para o próximo experimento):**
Um arquivo `eixos_conceituais.yaml` (ou `.json`) versionado no repositório Git, com uma estrutura como:

```yaml
versao_framework: "1.1"
eixos:
  - id: 0
    nome_curto: "Exaustão vs. Refrigério"
    autores_referencia: ["Byung-Chul Han"]
    descricao_ancora_zeroshot: >
      Estados de Fadiga Existencial e Alívio da Alma: ...
    descricao_prompt_llm: >
      Fadiga existencial, dor física/mental, lamento nas cinzas, busca por descanso.
```

O notebook passaria a **ler** esse arquivo em vez de redigitar as descrições em três células — eliminando a possibilidade de divergência silenciosa, e dando ao artigo uma seção de metodologia limpa: "o framework teórico está formalizado no Anexo/Repositório X, versão 1.1".

**Opção B — Framework teórico no próprio banco de dados (mais rigoroso, recomendado se a escala for o corpus completo):**
Substituir a tabela `topico` (que hoje só tem `id` e `antidoto_referencia`) por uma tabela mais rica (ver proposta detalhada em §7.1) que armazena as três redações lado a lado, mais uma coluna de versão. Isso tem uma vantagem adicional relevante para o artigo: permite **consultar e comparar formalmente**, via SQL, se e como a definição de um eixo mudou entre execuções do pipeline — uma forma natural de documentar a evolução metodológica entre o TCC e a versão para congresso.

### 6.3 Um problema conceitual mais profundo, escondido pela duplicação: o eixo "Narrativo/Normativo" não é um eixo de mesma natureza que os outros três

Vale destacar (e isso é independente de onde o texto está armazenado): os três primeiros eixos são dimensões existenciais genuínas (cada um com um polo negativo e um polo positivo, ancorado em um autor). O quarto ("Narrativo/Normativo") funciona, na prática, como uma **categoria residual/default** — é para onde tudo cai quando nenhum dos três eixos existenciais atinge o limiar de confiança (`decisao_id = 3` é o valor padrão em quase todos os ramos do `if/elif`). Misturar "um quarto eixo temático" com "a ausência de carga existencial suficiente" é uma inconsistência categorial que um revisor de PLN provavelmente vai apontar: um bom desenho experimental separaria:

1. Um **modelo de aplicabilidade** (binário): este versículo carrega conteúdo existencial ou é predominantemente narrativo/normativo?
2. Um **modelo de eixo dominante** (3 classes), aplicado apenas quando (1) responde "sim".

Isso também resolve, de quebra, o problema do desbalanceamento de classes esperado ao escalar para o corpus inteiro — livros genealógicos, legais e narrativos (grande parte do Antigo Testamento) vão, por natureza, produzir uma esmagadora maioria de casos "Narrativo", diluindo estatisticamente o sinal dos três eixos existenciais se tratados como uma classe qualquer em uma classificação 4-a-4. Separar em duas etapas é tanto mais correto teoricamente quanto mais robusto estatisticamente — e é um refinamento metodológico genuíno para destacar num artigo.

---

## 7. Aprofundamento — Validação do Modelo de Dados

O schema é funcional e já reflete boas práticas relacionais básicas (chaves estrangeiras, índices nos pontos certos). Mas, olhando com a lente de "isso vai sustentar um artigo de PLN e um corpus de 66 livros", há lacunas estruturais que valem a pena corrigir agora, antes de escalar — é muito mais barato ajustar o schema agora do que depois de povoar a Bíblia inteira.

### 7.1 `verso_topico`: colunas fixas por eixo (`p_exaustao`, `p_transitoriedade`, ...) acoplam o schema a exatamente 4 categorias
**Problema:** o modelo de dados atual é uma tabela "larga" (*wide table*), com uma coluna por eixo. Isso significa que o **schema em si está hardcoded ao número e à identidade dos eixos**, exatamente o problema conceitual do §6, agora manifestado na camada de dados. Se o framework evoluir (adicionar um 5º eixo, remover um eixo, ou — como sugerido no §6.3 — separar aplicabilidade de eixo dominante), será necessário um `ALTER TABLE` e reescrever queries em várias células.

**Intervenção proposta:** normalizar para uma tabela longa (*long table*):

```sql
CREATE TABLE IF NOT EXISTS "verso_topico_probabilidade" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "verso_id" INTEGER NOT NULL,
    "topico_id" INTEGER NOT NULL,
    "probabilidade" FLOAT NOT NULL,
    "execucao_id" INTEGER, -- ver 7.4
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (topico_id) REFERENCES topico(id)
);
```

Uma linha por (versículo, eixo), em vez de uma coluna por eixo. `verso_topico` continuaria existindo, mas apenas com a **decisão final** (`topico_id`, `status_decisao`, `margem_dominancia`, `entropia`, `gap_confianca`) — que são propriedades da decisão como um todo, não de um eixo específico. Ganho direto: adicionar/remover eixos vira um `INSERT` na tabela `topico`, não uma migração de schema; e fica trivial escrever consultas agregadas (`GROUP BY topico_id`) que hoje exigiriam `UNION` manual entre 4 colunas.

### 7.2 `topico`: falta de estrutura para o framework teórico (retomando o §6)
**Problema:** `topico(id, antidoto_referencia)` só guarda um rótulo curto — não há espaço para a descrição longa (âncora do BERTopic), a descrição para o prompt do LLM, os autores de referência ou uma versão do framework.

**Intervenção proposta:**

```sql
CREATE TABLE IF NOT EXISTS "topico" (
    "id" INTEGER PRIMARY KEY,
    "nome_curto" VARCHAR(100) NOT NULL,
    "antidoto_referencia" VARCHAR(100),
    "autores_referencia" VARCHAR(200),
    "descricao_ancora_zeroshot" TEXT NOT NULL,
    "descricao_prompt_llm" TEXT NOT NULL,
    "eh_categoria_residual" BOOLEAN DEFAULT 0, -- marca explicitamente o eixo 3 (ver §6.3)
    "versao_framework" VARCHAR(10) NOT NULL
);
```

Isso resolve ao mesmo tempo o problema de engenharia (fonte única de verdade) e dá ao artigo uma tabela citável: "o framework teórico utilizado está formalizado na tabela `topico`, versão 1.1, com N eixos, dos quais N-1 substantivos e 1 residual".

### 7.3 `verso_topico` e `rag_auditoria` como tabelas 1:1 por versículo — perda de granularidade semântica e de histórico
**Problema (granularidade semântica):** `verso_topico.verso_id` é chave primária, ou seja, **cada versículo só pode ter um eixo dominante**. Isso é uma simplificação forte para um corpus com paralelismo poético hebraico (comum em Jó, Salmos, Provérbios), onde um único versículo frequentemente contém duas orações paralelas que podem carregar ênfases existenciais diferentes (ex.: uma metade sobre exaustão, outra sobre uma súplica de sentido). Forçar um único rótulo por versículo descarta essa nuance — e é exatamente o tipo de sutileza linguística que um artigo de PLN sobre poesia bíblica se beneficiaria de capturar, não de esconder.

**Intervenção proposta:** permitir classificação multi-rótulo por versículo. Na prática, isso decorre naturalmente da normalização proposta em 7.1 (`verso_topico_probabilidade` já é 1-para-N por natureza) — a mudança adicional é de regra de negócio: em vez de "pegue o eixo de maior probabilidade e descarte o resto", permitir registrar **todos os eixos acima de um limiar conjunto** (ex.: os dois eixos mais prováveis, se ambos > 0.4) como coocorrentes no mesmo versículo. Isso também abre uma linha de pesquisa interessante para o artigo: segmentação sub-versicular (dividir o versículo em cláusulas antes de classificar, e depois agregar) — ver §8.2.

**Problema (perda de histórico):** `rag_auditoria.verso_id` também é chave primária (com `INSERT OR REPLACE`), então cada nova arbitragem **sobrescreve** a anterior. Se o pipeline for reexecutado após ajustar o corpus de comentários no Chroma, ou trocar de modelo Gemini, perde-se o registro de como a decisão mudou ao longo do tempo — justamente o tipo de evidência empírica valiosa para um artigo que queira demonstrar a evolução/estabilidade do método entre iterações.

**Intervenção proposta:** transformar `rag_auditoria` em um log append-only (chave primária `AUTOINCREMENT`, com uma coluna `criado_em` e sem `OR REPLACE`), preservando todas as tentativas de arbitragem já feitas para o mesmo versículo. Isso é praticamente "de graça" em custo de armazenamento e vira material direto para uma seção de resultados do tipo "comparamos a estabilidade das decisões de arbitragem entre a versão X e Y do pipeline".

### 7.4 Ausência de metadados de proveniência/execução (reprodutibilidade científica)
**Problema:** nenhuma tabela registra **qual execução do pipeline** gerou um dado — não há data, versão do código, modelo de embeddings usado, nem versão do modelo Gemini. Isso é aceitável numa PoC de TCC, mas é uma lacuna séria para uma submissão de congresso, onde reprodutibilidade e comparação entre execuções (ex.: "testamos com MiniLM e depois com o STS-PT, eis a diferença") são frequentemente exigidas por revisores.

**Intervenção proposta:**

```sql
CREATE TABLE IF NOT EXISTS "execucao_pipeline" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "data_execucao" TEXT NOT NULL,
    "modelo_embeddings_topico" VARCHAR(100),
    "modelo_embeddings_rag" VARCHAR(100),
    "modelo_llm_arbitragem" VARCHAR(100),
    "versao_framework_eixos" VARCHAR(10),
    "git_commit_hash" VARCHAR(40),
    "observacoes" TEXT
);
```

Com uma FK `execucao_id` em `verso_topico`, `verso_topico_probabilidade`, `rag_auditoria` e `verso_sentimento`. Isso permite, com uma única query, comparar os resultados de duas execuções diferentes do pipeline lado a lado — essencial para qualquer alegação de melhoria metodológica no artigo.

### 7.5 `genero_literario`/`livro`: granularidade de gênero por livro inteiro é grosseira demais
**Problema:** cada livro tem exatamente um `genero_id`. Isso já afeta a cascata de decisão (§3, item 3) hoje, mas o problema fica mais visível ao pensar no corpus completo: Salmos sozinho mistura lamento, hino, sabedoria, realeza; Daniel mistura narrativa (caps. 1–6) e apocalíptico (caps. 7–12); Provérbios e Cântico dos Cânticos são poéticos mas tematicamente muito diferentes entre si. Tratar o gênero como propriedade fixa do livro inteiro é uma simplificação que vai gerar limiares de decisão mal calibrados para subseções inteiras de livros "mistos".

**Intervenção proposta:** ver §8.1 — introduzir uma tabela de unidade literária com granularidade de capítulo/pericope, com seu próprio `genero_id`, e usar essa granularidade (não a do livro) na cascata de decisão da Célula 5.

### 7.6 Ausência de restrições de unicidade (`UNIQUE`) que protegem a integridade referencial
**Problema:** não há `UNIQUE (versao_id, livro_id, numero_capitulo, numero_verso)` em `verso`, nem `UNIQUE (nome)` em `genero_literario`/`versao`. Hoje a proteção contra duplicidade depende inteiramente da lógica da Célula 3 (checagem de contagem antes do seed) — se algum dia o seed for reexecutado parcialmente ou por um caminho diferente, nada no banco impede versículos duplicados.

**Intervenção proposta:** adicionar essas restrições agora, antes de escalar para 66 livros — é uma migração trivial hoje e dolorosa depois de o banco estar populado com o corpus completo e possivelmente já com duplicatas.

### 7.7 `chunks_comentario` não modela a fonte/obra do comentário
**Problema:** o schema assume implicitamente uma única obra de referência (o comentário Moody, visto pelo nome da coleção Chroma `comentario_moody_jo`), sem nenhuma tabela para representar "de qual obra/autor/edição veio este chunk". Isso limita a evolução natural (e desejável, do ponto de vista de rigor acadêmico) de comparar/triangular múltiplas fontes exegéticas para o RAG.

**Intervenção proposta:**

```sql
CREATE TABLE IF NOT EXISTS "fonte_comentario" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "titulo_obra" VARCHAR(150) NOT NULL,
    "autor" VARCHAR(150),
    "editora" VARCHAR(100),
    "ano_publicacao" INTEGER
);
```

com `chunks_comentario.fonte_id` como FK. Isso viabiliza, para o artigo, uma seção de "robustez do RAG a múltiplas fontes exegéticas" — um argumento de generalização que reviewers de PLN valorizam bastante em trabalhos de RAG aplicado a domínios especializados.

---

## 8. Aprofundamento — Tratamento do Corpus Bíblico (o Ponto Mais Crítico para a Escala Total)

Esta seção reúne os problemas que só aparecem (ou só importam de verdade) quando se pensa além de Jó — e são, na visão desta análise, os que mais merecem atenção antes de qualquer submissão, porque atacam a validade do método, não apenas sua implementação.

### 8.1 O versículo não é a unidade estrutural real do texto bíblico — e o pipeline trata como se fosse
**Problema:** a numeração de versículos é uma convenção editorial tardia (adicionada séculos depois da composição dos textos), não uma unidade discursiva ou poética original. O schema atual (`testamento` → `livro` → `verso`) não modela **nenhuma** estrutura literária intermediária: não há pericopes, não há marcação de trocas de interlocutor (fundamental em Jó, que é majoritariamente um diálogo dramático entre Jó, três amigos e Deus), não há marcação de estrofes poéticas, discursos proféticos ou unidades narrativas. Isso tem dois efeitos concretos e mensuráveis no pipeline atual:

- **O janelamento da Célula 5 (texto anterior + atual + posterior) ignora trocas de interlocutor.** Em Jó, um versículo de fechamento do discurso de Elifaz seguido pela abertura do discurso de Jó são tratados como vizinhos textuais comuns — o "contexto" injetado no embedding pode misturar a voz de dois personagens com posições teológicas opostas (um dos pontos centrais do livro de Jó é justamente o contraste entre essas vozes). Isso pode ruidificar exatamente o sinal que o pipeline tenta capturar.
- **A generalização para o corpus completo vai amplificar, não diluir, esse problema.** Em livros como Salmos (150 unidades poéticas curtas e independentes) ou Provérbios (sentenças isoladas, sem continuidade discursiva entre versículos vizinhos), o janelamento sequencial simples é ainda menos apropriado do que em Jó — versículos vizinhos frequentemente não têm relação temática alguma.

**Intervenção proposta:** introduzir uma tabela de unidade literária, com granularidade abaixo do livro e acima do versículo:

```sql
CREATE TABLE IF NOT EXISTS "unidade_literaria" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "livro_id" INTEGER NOT NULL,
    "capitulo_inicio" INTEGER NOT NULL,
    "verso_inicio" INTEGER NOT NULL,
    "capitulo_fim" INTEGER NOT NULL,
    "verso_fim" INTEGER NOT NULL,
    "tipo" VARCHAR(30), -- discurso, narrativa, hino, lamento, genealogia, lei...
    "interlocutor" VARCHAR(100), -- ex.: "Jó", "Elifaz", "Deus" — nulo quando não aplicável
    "genero_id" INTEGER, -- override do gênero do livro, quando necessário (ver 7.5)
    FOREIGN KEY (livro_id) REFERENCES livro(id),
    FOREIGN KEY (genero_id) REFERENCES genero_literario(id)
);
```

com `verso.unidade_literaria_id` como FK opcional. O janelamento da Célula 5 passaria a respeitar os limites dessa unidade (não olhar além dela para "anterior"/"posterior"), e a cascata de decisão da Célula 5 poderia usar o `genero_id` da unidade (quando presente) em vez do gênero fixo do livro inteiro — resolvendo também o problema do §7.5. Esse é, adicionalmente, um dado estruturado interessantíssimo para o artigo: permite perguntas de pesquisa como "os discursos de Jó (o personagem) concentram mais o eixo Exaustão do que os discursos de seus amigos?", que é exatamente o tipo de achado que dá substância a uma publicação nessa interseção de PLN e estudos bíblicos.

### 8.2 O versículo pode não ser a unidade certa de classificação, por causa do paralelismo poético hebraico
**Problema:** relacionado ao 8.1, mas na direção "sub-versicular". A poesia hebraica bíblica é estruturada primariamente por *parallelismus membrorum* — pares (ou trios) de orações curtas dentro do mesmo versículo que se reforçam, contrastam ou completam semanticamente. Classificar o versículo inteiro como um único vetor pode obscurecer o caso em que a primeira metade do versículo expressa um eixo e a segunda expressa outro (ou o mesmo eixo, de forma intensificada — o que também seria uma informação relevante, hoje perdida).

**Intervenção proposta (mais avançada, valiosa como contribuição de artigo):** oferecer, como camada opcional/experimental, uma segmentação sub-versicular — dividir versículos poéticos (identificáveis pelo `genero_id`/`tipo` da unidade literária) em cláusulas (ex.: por pontuação interna, "; ," ou por um segmentador sintático), classificar cada cláusula independentemente, e então agregar de volta ao nível do versículo (ex.: eixo dominante = maioria das cláusulas, ou manter o resultado multi-rótulo do §7.3). Isso é uma citação natural de trabalhos de PLN sobre paralelismo poético hebraico e coloca o trabalho em diálogo direto com a literatura de linguística computacional bíblica — reforçando a originalidade do artigo.

### 8.3 As âncoras semânticas do zero-shot foram desenhadas com o vocabulário específico de Jó, e provavelmente não generalizam sem validação
**Problema:** as descrições em `descricoes_eixos` usam imagens muito específicas do livro de Jó ("cinzas", "tempestade", "abismo", "feridas"). Isso é ótimo para Jó, mas não há nenhuma evidência no notebook de que essas âncoras foram testadas contra outros gêneros. Ao escalar para Salmos, Provérbios, Evangelhos ou Epístolas, o vocabulário típico dessas seções é bem diferente (ex.: Epístolas paulinas falam de exaustão/conflito de forma muito mais abstrata e doutrinária do que a linguagem visceral e corporal de Jó) — um classificador ancorado no vocabulário de Jó pode simplesmente não "reconhecer" a mesma dimensão existencial expressa em vocabulário diferente.

**Intervenção proposta:** antes de rodar o pipeline no corpus completo, validar a generalização das âncoras com uma amostra estratificada por gênero (retomando o gold standard do §5.3, mas agora com o objetivo específico de medir recall por gênero, não só por eixo). Se o recall cair fortemente fora de Jó/Poéticos, duas saídas são defensáveis para um artigo: (a) manter um único framework universal, mas reportar honestamente a variação de desempenho por gênero como um achado do estudo (uma limitação discutida é melhor do que uma generalização não testada), ou (b) adotar âncoras específicas por cluster de gênero, mantendo a mesma base teórica (Han/Bauman/Frankl) mas com vocabulário adaptado — o que reforça a necessidade da tabela de framework versionado do §6.2/7.2 (permitindo múltiplas "variantes por gênero" da mesma definição teórica, rastreáveis).

### 8.4 Uma única tradução (NVI) é usada, embora o schema já suporte múltiplas
**Problema:** a tabela `versao` já existe no schema exatamente para isso, mas o pipeline hoje opera sobre uma única tradução (NVI, pelo contexto do TCC). Para um artigo de PLN, isso deixa uma pergunta em aberto que reviewers tendem a levantar: os resultados são um artefato de como a NVI especificamente traduziu certas palavras hebraicas, ou refletem um padrão semântico mais robusto?

**Intervenção proposta:** aproveitar a estrutura já existente (`versao_id` em `verso`) para rodar o mesmo pipeline sobre pelo menos uma segunda tradução em português com filosofia de tradução diferente (ex.: uma tradução mais formal/literal como Almeida Revista e Atualizada, versus a NVI que é mais dinâmica/funcional), e reportar a concordância entre as classificações nas duas traduções como uma medida de robustez do método — um experimento de validação relativamente barato de implementar (o schema já suporta) e com bom retorno de credibilidade científica.

### 8.5 Textos com aparato crítico (variantes textuais) não são representados
**Problema:** ao expandir para o corpus completo — especialmente Evangelhos e algumas passagens do Antigo Testamento — é comum haver versículos com variantes textuais conhecidas (ex.: passagens que alguns manuscritos omitem, notas de rodapé de tradução indicando incerteza textual). O schema atual trata `verso.texto` como um dado único e definitivo, sem espaço para marcar esse tipo de incerteza filológica, que é diferente (mas relacionada) da incerteza semântica que o pipeline já modela (entropia/margem).

**Intervenção proposta:** não é urgente para a próxima submissão, mas vale registrar como limitação conhecida no artigo (é comum e aceitável em trabalhos de PLN bíblica citar isso como escopo/limitação), e, se houver tempo, adicionar um campo booleano simples `possui_variante_textual` em `verso` para permitir, no mínimo, excluir ou sinalizar esses casos nas análises de robustez.

---

## 9. Aprofundamento — RAG com o Gemini Gratuito

A pergunta central aqui é: **a implementação atual (retry com espera de 25s × tentativa + sleep de 2s entre chamadas) é adequada à capacidade real do free tier do Gemini?**

Segundo a documentação e guias atualizados de 2026, os modelos Flash do free tier operam hoje em torno de:
- **RPM (requisições por minuto):** ~15 para Flash / ~30 para Flash-Lite;
- **RPD (requisições por dia):** ~1.500 para Flash;
- **TPM (tokens por minuto):** entre 250 mil e 1 milhão, dependendo do modelo.

Com esses números, a análise da implementação atual é:

- **O `time.sleep(2)` entre chamadas é insuficiente como única defesa, mas funciona por sorte combinado com o retry.** Dois segundos entre chamadas equivalem a um teto teórico de 30 requisições/minuto — **acima** do limite de 15 RPM do Flash. O código *vai* bater no 429 com alguma regularidade sempre que o número de versículos críticos (`entropia > 0.80`) for razoavelmente alto; o retry existe para absorver esse erro esperado, não para evitá-lo. Isso funciona para uma PoC pequena (Jó tem ~1.070 versículos), mas **não escala** para o corpus completo sem ajuste.
- **Faltam limites de cota diária (RPD) no controle de fluxo.** Não há contador cumulativo de requisições no dia nem *circuit breaker* para interromper graciosamente o laço se a cota diária estiver perto do fim.
- **Intervenção proposta:** substituir o `sleep(2)` fixo por um *rate limiter* propriamente dito (token bucket respeitando 15 RPM) e um contador de chamadas/dia que interrompe o laço graciosamente (salvando progresso — o que já é natural, já que a arbitragem é linha a linha), retomando na sessão seguinte.
- **Escolha de modelo:** `gemini-2.5-flash-lite` (ou equivalente Flash-Lite disponível) tende a ser mais adequado que o Flash "padrão" para esse laço de arbitragem em lote, por oferecer o dobro do RPM no free tier a um custo de qualidade normalmente aceitável para uma tarefa de classificação estruturada em 4 categorias com JSON forçado.
- **Batching:** agrupar N versículos críticos (com seus contextos recuperados) em um único prompt, pedindo uma lista JSON de decisões, reduz o número de requisições ao custo de prompts maiores — como o TPM do free tier é folgado, essa troca costuma valer a pena.

**Conclusão desta seção:** a estratégia de retry é necessária e bem construída, mas trata como *exceção* algo que, dados os números reais do free tier, é *esperado com frequência*. Rate limiting proativo, `flash-lite` e *batching* de prompts tornariam o uso do Gemini gratuito mais previsível ao escalar para os 66 livros.

---

## 10. Aprofundamento — Uso Efetivo do ChromaDB

A pergunta feita foi: **até que ponto o ChromaDB é efetivamente utilizado nesta etapa?** A resposta é: **parcialmente** — cumpre bem seu papel central (busca vetorial com filtro de metadados), mas várias capacidades da ferramenta não aparecem, e há uma escolha estrutural que limita seu valor.

**O que está sendo bem aproveitado:**
- A combinação `query_embeddings` + `where` (filtro estrutural por capítulo/versículo) é exatamente o caso de uso para o qual o Chroma foi desenhado.
- A persistência local (`PersistentClient`) com cópia do Drive para o SSD do Colab antes da consulta é uma otimização de performance sensata.

**O que está subutilizado ou é uma fragilidade:**

1. **A ingestão dos comentários no ChromaDB não está neste notebook**, e não há garantia visível de que o modelo de embeddings usado para indexar (desconhecido, em outro script) é o mesmo usado aqui para consultar (`paraphrase-multilingual-MiniLM-L12-v2`). Se divergirem, a busca por cosseno é matematicamente inválida, sem que o Chroma acuse erro.
   - **Intervenção:** gravar o nome/versão do modelo de embeddings como metadado da própria coleção Chroma na ingestão, e validar esse metadado no início da Célula 5.1 antes de qualquer consulta.
2. **Redundância de proveniência entre `chunks_comentario` (SQLite) e os metadados do Chroma** — os mesmos campos (`capitulo_inicio`, `pagina_origem` etc.) existem duplicados em dois sistemas sem mecanismo de sincronização.
   - **Intervenção:** usar `chunks_comentario` como fonte única de verdade, armazenando no Chroma apenas `chunk_id` + texto + embedding, e recuperando metadados via `JOIN` no SQLite a partir do `chunk_id` retornado.
3. **`score_similaridade` é calculado e persistido, mas nunca usado para decidir se o contexto recuperado é confiável** antes de injetá-lo no prompt do Gemini.
   - **Intervenção:** definir um limiar mínimo de similaridade abaixo do qual o contexto não é injetado, registrando `status_decisao = "RAG_sem_contexto_relevante"` nesse caso.
4. **Ausência de reranking ou fusão híbrida (BM25 + vetor)** — problemático justamente para comentários teológicos que citam nomes próprios específicos, onde busca puramente densa pode perder um chunk relevante por distância vetorial, mesmo contendo o termo exato.

**Conclusão desta seção:** o ChromaDB está funcionando como um índice vetorial competente, mas o pipeline não aproveita seu potencial de auditoria de proveniência do embedding, não usa o próprio score que calcula, e mantém uma duplicação de metadados que é um risco de manutenção — vale fechar essa lacuna entre o que o schema promete (§7.7) e o que o código garante.

---

## 11. Roteiro de Melhorias Priorizado

| Prioridade | Intervenção | Esforço | Ganho esperado |
|---|---|---|---|
| **Crítica** | Formalizar o framework de eixos como fonte única de verdade (config ou tabela `topico` expandida) — §6 | Médio | Elimina deriva semântica entre BERTopic/prompt/rótulo; pré-requisito para tudo mais |
| **Crítica** | Validar generalização das âncoras por gênero antes de escalar — §8.3 | Alto | Evita publicar um método que só funciona em Jó |
| **Crítica** | Normalizar `verso_topico` (colunas fixas → tabela longa) — §7.1 | Médio | Schema deixa de estar acoplado a 4 eixos fixos |
| Alta | Modelar unidade literária (pericope/interlocutor) e corrigir janelamento — §8.1 | Alto | Corrige vazamento de contexto entre falas/personagens; abre pergunta de pesquisa nova |
| Alta | Unificar modelo de embeddings entre BERTopic e ChromaDB — §5.1 | Médio | Consistência semântica, comparabilidade |
| Alta | Rate limiting proativo para o Gemini (RPM/RPD) — §9 | Baixo | Menos falhas, uso previsível do free tier |
| Alta | Tabela `execucao_pipeline` para proveniência/reprodutibilidade — §7.4 | Baixo | Pré-requisito para qualquer comparação entre versões do método no artigo |
| Média | Separar "aplicabilidade existencial" de "eixo dominante" (2 estágios) — §6.3 | Médio | Corrige mistura categorial do eixo residual; robustez estatística |
| Média | Permitir classificação multi-rótulo por versículo — §7.3 | Médio | Captura paralelismo poético hebraico |
| Média | Validar limiares com gold standard e métricas — §5.3 | Alto | Legitimidade científica dos resultados |
| Média | Rodar pipeline em 2ª tradução para validar robustez — §8.4 | Médio | Argumento de generalização exigido por revisores |
| Média | Usar `score_similaridade` como filtro de confiança no RAG — §10 | Baixo | Evita contexto irrelevante no prompt do LLM |
| Média | Parametrizar `livro_id` — §5.5 | Médio | Escala do PoC para o corpus completo |
| Baixa | `rag_auditoria` como log append-only — §7.3 | Baixo | Preserva histórico de arbitragens entre execuções |
| Baixa | Transações atômicas DELETE+INSERT — §5.8 | Baixo | Consistência em caso de falha |
| Baixa | Fixar versões de dependências — §5.9 | Baixo | Reprodutibilidade para revisão por pares |
| Baixa | Reranking híbrido BM25+vetor no Chroma — §10 | Alto | Precisão de recuperação em nomes próprios |
| Baixa | Modelar fonte/obra dos comentários (`fonte_comentario`) — §7.7 | Baixo | Viabiliza triangulação de múltiplas fontes exegéticas |
| **Inovação** | Enriquecer o corpus com dados morfológicos hebraico/grego originais (OSHB/STEPBible/MorphGNT) — §12.1 | Alto | Feature léxico-semântica direta (ex.: lema *hevel*) triangulando o eixo neural |
| **Inovação** | Modelo local (open-weight, quantizado) substituindo o Gemini remoto na arbitragem — §12.2 | Alto | Zero dependência de cota/custo externo; reprodutibilidade total offline |
| **Inovação** | Gold standard multi-anotador com Label Studio + Kappa/Alpha — §12.3 | Médio | Operacionaliza a validação estatística do §5.3 com ferramenta concreta |
| **Inovação** | Grafo de interlocutores × eixos (NetworkX/Gephi) — §12.4 | Médio | Nova forma de visualização/achado para a apresentação em congresso |
| **Inovação** | Rastreamento de experimentos (MLflow/DVC, self-hosted) — §12.5 | Médio | Reprodutibilidade científica formal, complementa §7.4 |
| **Inovação** | Baseline com LDA/NMF não supervisionado — §12.6 | Baixo | Justifica cientificamente a escolha do zero-shot supervisionado por âncoras |
| **Inovação** | Explicabilidade neural (Captum/attention rollout) complementando a justificativa do LLM — §12.7 | Médio | XAI em duas camadas: simbólica (texto do LLM) + neural (atribuição) |
| **Inovação** | Validação estatística com bootstrapping/testes de permutação — §12.8 | Baixo | Intervalos de confiança reais, não apenas estimativas pontuais |
| **Inovação** | Publicar dataset e framework no Hugging Face Hub — §12.9 | Baixo | Recurso reutilizável pela comunidade; valorizado por revisores |
| **Inovação** | Demo interativa gratuita (HF Spaces + Gradio) — §12.10 | Baixo | Visibilidade e reprodutibilidade para revisores/comunidade |

---

## 12. Evoluções Adicionais — Inovação Livre (Tecnologias Gratuitas)

Esta seção responde ao pedido de propor evoluções sem restrição de escopo, com a única condição de que sejam gratuitas — adequado à fase acadêmica do trabalho. Antes de detalhar, um ponto de contexto que vale registrar no artigo: o problema de aplicar *distant reading* e modelagem de tópicos a textos bíblicos já tem alguma tradição em Humanidades Digitais (ver, por exemplo, o trabalho "Modeling the Hebrew Bible: Potential of Topic Modeling Techniques", que discute o uso de topic modeling sobre a Bíblia Hebraica). Situar o trabalho explicitamente nessa linha de pesquisa (Humanidades Digitais + PLN aplicado a corpora religiosos/canônicos), citando esse tipo de precedente, fortalece a seção de trabalhos relacionados de uma submissão a congresso — hoje a metodologia (Han/Bauman/Frankl) é citada, mas o próprio *método computacional* carece dessa ancoragem na literatura de PLN/DH.

### 12.1 Enriquecer o corpus com o texto original (hebraico/grego) usando fontes abertas — e transformar isso em uma nova fonte de evidência, não só em curiosidade filológica

**Ideia:** hoje o pipeline classifica exclusivamente sobre a tradução portuguesa. Existem datasets abertos e gratuitos, de qualidade acadêmica, com o texto original lematizado e morfologicamente anotado:

- **Open Scriptures Hebrew Bible (OSHB)** — Códice de Leningrado (WLC) com lemas e números de Strong, licença CC BY 4.0 (texto em domínio público).
- **STEPBible-Data** — conjuntos TSV com Hebraico e Grego totalmente tageados morfologicamente e semanticamente, licença CC BY 4.0.
- **MorphGNT / SBLGNT** — Novo Testamento grego com morfologia completa.

**Por que isso é mais do que "enriquecer o dado":** o eixo "Vazio vs. Propósito" (base Bauman) tem uma relação direta e citável com o conceito hebraico de **הֶבֶל (*hevel*)** — a palavra central de Eclesiastes (tradicionalmente traduzida "vaidade" ou "fugacidade") e que também aparece em Jó. Isso permite construir uma **feature léxico-simbólica independente do modelo neural**: contar/ponderar a presença do lema `hevel` (via número de Strong, ex. H1892) e de outros lemas teologicamente carregados (ex. יגע/*yaga* para fadiga, no eixo Exaustão) em cada versículo, e usar essa contagem como um **sinal de triangulação** — se a classificação neural (BERTopic/embeddings) concorda com a presença do lema hebraico esperado, isso é evidência de validade convergente; se discorda sistematicamente, é um achado interessante por si só (ex.: "o modelo captura o eixo semântico mesmo quando o lema-fonte não está presente, sugerindo generalização além do vocabulário lexical direto").

**Implementação:** baixar os dados do OSHB/STEPBible (arquivos estáticos, sem custo, sem API), alinhar por referência (livro/capítulo/versículo, já compatível com o schema atual) em uma nova tabela `verso_original` (`verso_id`, `lingua`, `texto_original`, `lemas_strong` como JSON ou tabela normalizada `verso_lema`), e adicionar ao pipeline uma etapa (nova célula) que calcula a feature léxica e a compara com a decisão neural. Isso é, ao mesmo tempo, uma evolução metodológica genuína e um diferencial de originalidade forte para o artigo — poucos trabalhos de PLN em português cruzam BERTopic/embeddings com anotação lexical do hebraico bíblico original.

### 12.2 Remover a dependência de uma API remota paga/limitada na arbitragem, usando um modelo aberto local

**Ideia:** hoje a arbitragem depende do Gemini (free tier, mas ainda assim uma API remota com cota e — potencialmente — custo se o free tier for excedido). Para uma fase acadêmica, é possível eliminar completamente essa dependência substituindo (ou, melhor, comparando lado a lado) por um modelo de pesos abertos (*open-weight*) rodando localmente no próprio ambiente gratuito do Colab:

- **Gemma 2 (2B/9B)** ou **Llama 3.2 (1B/3B)** ou **Mistral 7B**, quantizados em 4-bit (via `bitsandbytes` ou `llama.cpp`/GGUF), rodam confortavelmente na GPU T4 gratuita do Colab.
- Modelos com maior familiaridade em português especificamente: **Gervásio-PT** (Universidade de Lisboa, aberto) ou fine-tunes em português de Llama/Mistral (ex. **Bode**), que podem ter desempenho melhor que um modelo genérico multilíngue para a tarefa de arbitragem em português.
- Bibliotecas de serving locais gratuitas: **Ollama** (API local compatível, roda no próprio Colab ou numa máquina pessoal) ou diretamente `transformers` + `bitsandbytes`.

**Ganho concreto:** (a) zero custo e zero limite de RPM/RPD — elimina toda a discussão do §9 sobre rate limiting; (b) **reprodutibilidade total**: um revisor ou outro pesquisador pode rodar o pipeline inteiro sem precisar de uma chave de API do Google, o que é um diferencial forte para reprodutibilidade científica; (c) abre a porta para um **experimento comparativo genuíno** no artigo — "comparamos a concordância de arbitragem entre Gemini (proprietário) e um modelo aberto local (Gemma 2 9B) nos mesmos versículos de alta ambiguidade", o que é uma contribuição de pesquisa por si só (avaliação de LLMs proprietários vs. abertos em uma tarefa de classificação teológica-existencial em português, um domínio de nicho onde essa comparação provavelmente não existe na literatura).

### 12.3 Gold standard multi-anotador com ferramenta dedicada, calculando concordância inter-anotador

**Ideia:** a validação proposta no §5.3 (rotular uma amostra) fica muito mais rigorosa e citável se feita com uma ferramenta própria de anotação, não em uma planilha. **Label Studio** é open-source, gratuito, self-hostável (inclusive dentro do próprio Colab via túnel, ou localmente), e suporta exatamente o tipo de tarefa aqui (classificação de texto em categorias, com múltiplos anotadores).

**Ganho:** além de operacionalizar a validação, permite calcular formalmente a **concordância inter-anotador** (Cohen's Kappa para 2 anotadores — você e seu coautor —, ou Krippendorff's Alpha para mais anotadores/categorias) usando bibliotecas gratuitas (`scikit-learn`, `statsmodels`, ou `krippendorff` no PyPI). Reportar esse número é praticamente uma exigência implícita de qualquer revisor de PLN antes de aceitar qualquer alegação de "o gold standard mostra X% de acerto" — sem concordância inter-anotador reportada, o próprio gold standard é questionável.

### 12.4 Modelar e visualizar a rede de interlocutores × eixos existenciais como um achado quantitativo novo

**Ideia:** retomando a proposta da tabela `unidade_literaria` (com o campo `interlocutor`) do documento anterior — uma vez que essa estrutura exista, é possível construir um **grafo bipartido** (personagem ↔ eixo existencial, com peso = frequência/intensidade) usando **NetworkX** (gratuito, puro Python) para análise e **Gephi** (gratuito, open-source) para visualização exportável.

**Por que isso é uma contribuição, não só uma visualização bonita:** Jó é estruturalmente um debate entre vozes com posições teológicas antagônicas (Jó, os três amigos, Eliú, a voz de Deus no redemoinho). Uma rede que mostra, por exemplo, "os discursos de Jó concentram-se fortemente no eixo Exaustão e secundariamente em Vazio, enquanto os discursos dos amigos concentram-se em Transitoriedade/Solidez (argumentos sobre a ordem retributiva)" é ao mesmo tempo uma validação computacional de uma leitura teológica clássica do livro **e** um resultado quantitativo genuinamente interessante para uma audiência de PLN computacional aplicada a texto literário/religioso — o tipo de figura que costuma abrir ou fechar um artigo desse tipo.

### 12.5 Rastreamento de experimentos e versionamento de dados/modelos

**Ideia:** complementando a tabela `execucao_pipeline` proposta no documento anterior (§7.4), adotar ferramentas dedicadas e gratuitas de MLOps acadêmico:

- **MLflow** (open-source, self-hospedável gratuitamente, inclusive dentro do próprio Colab com armazenamento no Drive) para registrar cada execução (parâmetros, métricas, artefatos) de forma consultável via UI.
- **DVC (Data Version Control)** (gratuito, integra com Git) para versionar o próprio banco SQLite/coleção Chroma como "dados", permitindo reverter para uma versão anterior do corpus processado ou comparar diffs entre execuções — resolve de forma robusta o problema de reprodutibilidade mencionado em várias seções anteriores (§5.9, §7.4).

**Ganho:** transforma "rodei de novo e os números mudaram um pouco" de um problema silencioso em um experimento documentado e comparável — essencial ao iterar o pipeline várias vezes antes de uma submissão.

### 12.6 Baseline não supervisionado clássico (LDA/NMF) para justificar cientificamente a escolha metodológica

**Ideia:** todo artigo que propõe uma abordagem específica (aqui, zero-shot com âncoras teóricas) se beneficia de compará-la explicitamente com uma abordagem clássica mais simples, para demonstrar que a complexidade adicional se justifica. Rodar **LDA (Latent Dirichlet Allocation)** ou **NMF (Non-negative Matrix Factorization)** — ambos disponíveis gratuitamente via `gensim`/`sklearn`, sem necessidade de GPU — sobre o mesmo corpus (Jó, e depois o corpus completo), e comparar os tópicos emergentes não supervisionados com os 4 eixos teóricos pré-definidos.

**Ganho:** é o tipo de "baseline de comparação" que revisores de PLN esperam ver por padrão — sem ele, a pergunta "por que não usar simplesmente LDA, que é padrão e mais simples?" fica sem resposta empírica no artigo.

### 12.7 Explicabilidade neural complementando a explicabilidade textual do LLM

**Ideia:** hoje a "explicabilidade" do pipeline vem inteiramente da `justificativa` textual gerada pelo Gemini (uma explicação em linguagem natural, mas gerada por um segundo modelo, não pelo classificador original). Para o classificador neural em si (BERTopic/embeddings), é possível adicionar uma camada de explicabilidade baseada em atribuição, usando bibliotecas gratuitas como **Captum** (PyTorch, Meta, open-source) ou técnicas de *attention rollout* sobre o BERTimbau, para visualizar **quais palavras do versículo mais contribuíram** para a similaridade com cada eixo.

**Ganho:** cria uma segunda camada de XAI, independente e complementar à primeira (textual/LLM) — uma seção de "explicabilidade em duas camadas: simbólica e neural" é metodologicamente rica e demonstra maturidade em XAI, um tema que costuma ser bem recebido em avaliações de PLN aplicado.

### 12.8 Validação estatística com intervalos de confiança reais (bootstrapping)

**Ideia:** as métricas de precisão/revocação propostas no §5.3 do documento anterior, se calculadas apenas como um número pontual sobre uma amostra pequena (50–100 versículos), têm alta variância. Usar **bootstrapping** (reamostragem com reposição, `scipy`/`numpy`, gratuito) para calcular intervalos de confiança em torno de cada métrica, e **testes de permutação** para comparar estatisticamente se a diferença entre duas configurações (ex.: duas traduções, dois modelos de embedding, com/sem RAG) é estatisticamente significativa, não apenas numericamente diferente.

**Ganho:** eleva o rigor estatístico das alegações do artigo de "o método com RAG teve X% a mais de acerto" para "o método com RAG teve X% a mais de acerto (IC 95%: [a, b], p < 0.05)" — o padrão esperado em publicações de PLN com avaliação empírica.

### 12.9 Publicar o dataset anotado e o framework teórico como recurso aberto

**Ideia:** disponibilizar, no **Hugging Face Hub** (hospedagem gratuita de datasets) ou em um repositório GitHub dedicado, (a) o gold standard anotado (§12.3), (b) o framework de eixos versionado (config do §6.2), e (c) os embeddings/resultados do corpus processado.

**Ganho:** para congressos de PLN, disponibilizar um recurso reutilizável (não apenas um artigo) é frequentemente um diferencial de aceitação e de impacto (citações futuras). Também é uma forma de contribuição concreta e gratuita — não exige nenhuma infraestrutura paga, apenas organização dos artefatos já produzidos pelo próprio pipeline.

### 12.10 Demonstração interativa gratuita para revisores e comunidade

**Ideia:** publicar uma demo simples em **Hugging Face Spaces** (hospedagem gratuita) usando **Gradio** ou **Streamlit** (ambos gratuitos e open-source), onde qualquer pessoa possa inserir uma referência bíblica (ou navegar pelo livro de Jó) e ver a classificação por eixo, a probabilidade, e — quando aplicável — a justificativa do RAG.

**Ganho:** transforma um resultado estático (tabelas em um notebook) em algo explorável, o que ajuda tanto na apresentação em congresso (uma demo ao vivo é sempre mais impactante que slides) quanto na avaliação por revisores que queiram inspecionar casos específicos além dos exemplos citados no artigo.

---

## 13. Conclusão

O pipeline demonstra maturidade de engenharia acima do usual para um trabalho de MBA — idempotência de carga, deleção seletiva, quantificação de incerteza acionando decisões de custo/qualidade, e uma trilha de auditoria para o RAG são escolhas de design que já diferenciam o trabalho. Mas a transição de "PoC de TCC restrita a Jó" para "contribuição defensável em congresso de PLN" exige resolver três frentes que são, na prática, uma só: **o framework teórico dos eixos existenciais precisa parar de viver como texto duplicado em três lugares do código e passar a ser um dado versionado e único** (§6); **o modelo de dados precisa deixar de estar acoplado a exatamente 4 eixos e a um versículo = uma unidade semântica** (§7); e **o tratamento do corpus precisa reconhecer que o versículo não é a unidade estrutural real do texto bíblico**, tanto acima (pericopes, interlocutores) quanto abaixo (paralelismo poético) dele (§8).

Além dessas correções estruturais, o §12 propõe um segundo eixo de evolução — não mais corretivo, mas de **inovação aberta**: ancorar o trabalho na literatura de Humanidades Digitais já existente sobre modelagem de tópicos em textos bíblicos; cruzar a classificação neural com o texto original hebraico/grego via fontes abertas (uma feature léxico-simbólica genuinamente nova, ligada diretamente ao conceito de *hevel*/vaidade do eixo Bauman); eliminar a dependência de uma API remota substituindo-a por um modelo aberto local, o que resolve de uma vez o problema de cota do free tier **e** abre um experimento comparativo publicável por si só (LLM proprietário vs. aberto); e adotar prática de MLOps acadêmico (rastreamento de experimentos, versionamento de dados, publicação aberta do dataset e de uma demo) que são, hoje, cada vez mais esperadas — e valorizadas — em submissões de PLN. Todas essas propostas usam exclusivamente ferramentas e dados gratuitos, coerentes com a fase acadêmica do trabalho, e cada uma delas é, ao mesmo tempo, uma correção de risco técnico e uma fonte legítima de contribuição e de pergunta de pesquisa nova — o que as torna um investimento de tempo particularmente bem direcionado nesta fase do trabalho.
