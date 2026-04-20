# Dicionário de Dados - Documentação do Projeto
**Arquivo de Origem:** `01-schema.sql`[cite: 2]

Este documento detalha a finalidade de cada tabela e coluna do modelo de dados para o TCC de MBA em Engenharia de Software.

---

## 1. Estrutura Bíblica (Base NVI)
Tabelas que armazenam a hierarquia e o conteúdo textual original.

### Tabela: `versao`
Armazena as edições ou traduções da Bíblia.[cite: 2]
* **id**: Chave primária identificadora da versão.[cite: 2]
* **sigla**: Abreviação da versão (ex: NVI, ARA).[cite: 2]
* **nome**: Nome completo da tradução.[cite: 2]

### Tabela: `testamento`
Classifica os blocos bíblicos.[cite: 2]
* **id**: Chave primária.[cite: 2]
* **nome**: Nome do testamento (ex: Antigo Testamento).[cite: 2]

### Tabela: `genero_literario`
Categoriza o estilo de escrita dos livros.[cite: 2]
* **id**: Chave primária com incremento automático.[cite: 2]
* **nome**: Descrição do gênero (ex: Sabedoria, Evangelhos).[cite: 2]

### Tabela: `livro`
Catálogo de livros bíblicos e suas relações.[cite: 2]
* **id**: Chave primária.[cite: 2]
* **nome**: Nome do livro.[cite: 2]
* **abreviacao**: Sigla curta do livro.[cite: 2]
* **testamento_id**: Chave estrangeira ligada à tabela `testamento`.[cite: 2]
* **genero_id**: Chave estrangeira ligada à tabela `genero_literario`.[cite: 2]

### Tabela: `verso`
O repositório principal das sentenças bíblicas.[cite: 2]
* **id**: Chave primária com incremento automático.[cite: 2]
* **versao_id**: Chave estrangeira referenciando `versao`.[cite: 2]
* **livro_id**: Chave estrangeira referenciando `livro`.[cite: 2]
* **numero_capitulo**: Identificador numérico do capítulo.[cite: 2]
* **numero_verso**: Identificador numérico do versículo.[cite: 2]
* **texto**: Conteúdo textual integral do verso.[cite: 2]

---

## 2. Camada de Processamento PLN
Refinamento textual para análise computacional.

### Tabela: `verso_limpo`
* **verso_id**: Chave primária e estrangeira vinculada ao `verso` original.[cite: 2]
* **texto_limpo**: Conteúdo após normalização e remoção de ruídos (stop words, etc).[cite: 2]

---

## 3. Camada de Classificação Existencial (BERTopic)
Dados sobre a extração de tópicos e métricas de confiança.

### Tabela: `topico`
* **id**: Chave primária.[cite: 2]
* **antidoto_referencia**: Descrição do eixo temático ou referência conceitual (ex: Esgotamento).[cite: 2]

### Tabela: `verso_topico`
Mapeamento de versos para eixos existenciais com métricas estatísticas.[cite: 2]
* **verso_id**: Chave primária e estrangeira vinculada ao `verso`.[cite: 2]
* **topico_id**: Chave estrangeira vinculada ao `topico`.[cite: 2]
* **p_exaustao / p_transitoriedade / p_vazio / p_narrativo**: Probabilidades calculadas para cada categoria.[cite: 2]
* **similaridade_final**: Score de proximidade semântica.[cite: 2]
* **margem_dominancia**: Diferença entre a maior e a segunda maior probabilidade.[cite: 2]
* **status_decisao**: Rótulo do status final da classificação.[cite: 2]
* **entropia**: Grau de incerteza da predição.[cite: 2]
* **gap_confianca**: Intervalo de confiança entre as predições.[cite: 2]

---

## 4. Análise de Sentimento (BERTimbau)
Resultados da polaridade emocional dos versos.

### Tabela: `verso_sentimento`
* **verso_id**: Chave primária e estrangeira vinculada ao `verso`.[cite: 2]
* **label**: Classificação categórica (POS, NEU, NEG).[cite: 2]
* **sentimento_num**: Valor numérico da polaridade (1, 0, -1).[cite: 2]
* **score_pos / score_neg / score_neu**: Valores flutuantes de confiança para cada categoria.[cite: 2]