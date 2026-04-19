# 📖 Arquiteturas Transformers e Aprendizado Zero-Shot na Classificação de Eixos Existenciais no Texto Bíblico

![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-%23EE4C2C.svg?style=for-the-badge&logo=PyTorch&logoColor=white)
![HuggingFace](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-Spaces-yellow?style=for-the-badge)

Este projeto de Trabalho de Conclusão de Curso (MBA em Engenharia de Software) utiliza técnicas de **Processamento de Linguagem Natural (PLN)** para analisar o texto bíblico (NVI) sob a ótica da psicologia existencial e sociologia contemporânea.

O objetivo é identificar "antídotos" nas escrituras para as angústias descritas por:
* **Viktor Frankl:** O vazio existencial e a busca de sentido.
* **Zygmunt Bauman:** A fragilidade dos laços e a incerteza da modernidade líquida.
* **Byung-Chul Han:** A exaustão e a fadiga na sociedade do desempenho.

---

## 🛠️ Arquitetura de Dados e Tecnologias

Diferente de abordagens puramente estatísticas, este projeto implementa uma arquitetura que integra modelos de linguagem de larga escala com camadas de regras de negócio:

* **IA Explicável (XAI):** Auditoria via entropia e similaridade cosseno para validar a confiança das classificações.
* **Thresholds de Especialista:** Implementação de limiares de decisão para mitigar o ruído em textos de alta concisão ou polissêmicos.
* **Modelagem Zero-Shot:** Classificação de eixos existenciais sem necessidade de treinamento prévio rotulado, utilizando `BERTopic`.
* **Análise de Sentimento:** Uso do modelo `BERTimbau` para capturar a polaridade afetiva no português brasileiro.

### 🗄️ Modelagem do Banco de Dados
O sistema utiliza **SQLite** para garantir a rastreabilidade total, desde o metadado do versículo até o *gap* de confiança da predição.

Para detalhes sobre as tabelas, tipos de dados e o **Diagrama de Entidade-Relacionamento (ER)** renderizado via Mermaid, acesse:
👉 **[Documentação da Arquitetura de Dados (database.md)](docs/database.md)**

---

## 🎓 Etapas do Processamento

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Arial',
    'fontSize': '12px',
    'clusterBkg': '#ffffff',
    'clusterBorder': '#cbd5e1',
    'nodeSpacing': 10,
    'clusterPadding': 15
  }
}}%%
graph LR
    %% Direção Geral do Pipeline

    subgraph Camada1 ["1. INFRAESTRUTURA E CARGA"]
        direction TB
        E1["<b>Etapa 1: Setup</b><br/>Google Drive e SQLite<br/><i>libs: google.colab, os</i>"]
        E2["<b>Etapa 2: Ambiente</b><br/>GPU e Scripts DDL<br/><i>libs: transformers, torch, sqlite3</i>"]
        E3["<b>Etapa 3: Ingestão</b><br/>Consistência do Corpus<br/><i>libs: sqlite3</i>"]
        %% Forçar verticalidade
        E1 ~~~ E2 ~~~ E3
    end

    subgraph Camada2 ["2. PREPARAÇÃO"]
        direction TB
        E4["<b>Etapa 4: Filtragem</b><br/>POS Tagging e Limpeza<br/><i>libs: spacy, pandas, re</i>"]
        P2["<i>Foco: Mitigação de ruído<br/>nominal e genealogias</i>"]
        %% Forçar verticalidade
        E4 ~~~ P2
    end

    subgraph Camada3 ["3. INTELIGÊNCIA (NLP E XAI)"]
        direction TB
        E5["<b>Etapa 5: Classificação</b><br/>Zero-Shot (BERTopic)<br/><i>libs: bertopic, sklearn, tqdm</i>"]
        I2["<b>Auditoria XAI</b><br/>Gap de Confiança e Entropia<br/><i>libs: numpy, pandas</i>"]
        E6["<b>Etapa 6: Sentimento</b><br/>BERTimbau Contextual<br/><i>libs: pysentimiento, tqdm</i>"]
        %% Forçar verticalidade
        E5 ~~~ I2 ~~~ E6
    end

    subgraph Camada4 ["4. ENTREGA"]
        direction TB
        E7["<b>Etapa 7: Resultados</b><br/>Cruzamento Estatístico<br/><i>libs: matplotlib, seaborn, wordcloud</i>"]
        A2["<i>Foco: Validação de<br/>Antídotos Existenciais</i>"]
        %% Forçar verticalidade
        E7 ~~~ A2
    end

    %% Fluxo de Dados Principal
    Camada1 ==> Camada2
    Camada2 ==> Camada3
    Camada3 ==> Camada4

    %% Estilos
    style Camada1 fill:#f8fafc,stroke:#475569,stroke-width:2px
    style Camada2 fill:#fff7ed,stroke:#ea580c,stroke-width:2px
    style Camada3 fill:#eff6ff,stroke:#2563eb,stroke-width:2px
    style Camada4 fill:#f0fdf4,stroke:#16a34a,stroke-width:2px
```

---

## 📂 Estrutura do Repositório

```text
├── data/                            # Banco de dados .db (git-ignored).
│   ├── base-dados-final.db          # Versão final da base de dados, completa.
├── docs/
│   ├── database.md                  # Documentação técnica e diagrama do modelo de dados.
├── notebooks/
│   ├── 01-processamento_pln.ipynb   # Pipeline de limpeza, BERTopic e Sentimento.
│   └── 02-visualizacao_resultados.ipynb # Extração de insights e visualização de dados.
│   └── 03-geracao-fluxos-dados.ipynb # Apoio à geração de imagens 
├── sql/
│   └── queries/
│       └── 01-dados-graficos.sql    # Consultas SQL para geração dos gráficos.
│       └── 02-validacoes.sql        # Consultas SQL para auditoria dos resultados.
│   ├── 01-schema.sql                # Definição de todas as tabelas e índices.
│   ├── 02-seed_data.sql             # População do texto bíblico e metadados.
└── README.md                        # Documentação do projeto.
```

---

## 🎓 Autoria
* **Heber Davi Salcedo Rodrigues** - *Especialista em Engenharia de Software*
* **Orientador:** Prof. Dr. Orlando Da Silva Junior
