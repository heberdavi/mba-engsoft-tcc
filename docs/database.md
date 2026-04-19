# Documentação do Modelo de Dados e Arquitetura de Informação

Este artefato descreve a estrutura do banco de dados relacional utilizado no projeto de análise de sentimentos e classificação existencial de textos bíblicos. A arquitetura foi desenhada para suportar um pipeline de Processamento de Linguagem Natural (PLN) que integra modelos Transformers (BERTimbau e BERTopic) ao corpus textual.

## 1. Visão Geral da Arquitetura
O modelo de dados é dividido em quatro camadas lógicas:
1. **Camada de Domínio (Base):** Estrutura canônica da Bíblia (Livros, Testamentos e Gêneros).
2. **Camada de Texto (Versos):** O átomo da análise, preservando a integridade das versões.
3. **Camada de Processamento (NLP):** Armazenamento de textos limpos (pré-processamento).
4. **Camada de Inteligência (Inference):** Resultados de classificação de tópicos (Eixos de Exaustão vs. Refrigério, Transitoriedade vs. Solidez, Vazio vs. Propósito e Narrativo/Normativo) e análise de sentimento.

## 2. Diagrama de Entidade-Relacionamento

```mermaid
%%{init: {
  'theme': 'default',
  'themeVariables': {
    'fontFamily': 'Arial',
    'fontSize': '40px',
    'background': '#ffffff',
    'mainBkg': '#ffffff',
    'canvasBackground': '#ffffff'
  },
  'themeCSS': ' .entityBox { stroke-width: 2px; fill: white !important; } .entityLabel { font-weight: bold; font-size: 24px !important; } .edgeLabel { font-size: 20px !important; background-color: white !important; padding: 2px; } rect { fill: white !important; } g.classGroup rect { fill: white !important; } .mermaid { background-color: white !important; } '
}}%%
erDiagram
    direction LR
    %% 1. ESTRUTURA BÁSICA
    testamento ||--o{ livro : "agrupa"
    genero_literario ||--o{ livro : "define"
    versao ||--o{ verso : "contém"
    livro ||--o{ verso : "possui"

    %% 2, 3 e 4. CAMADAS DE PROCESSAMENTO
    verso ||--|| verso_limpo : "limpeza"
    verso ||--|| verso_topico : "NLP/XAI"
    verso ||--|| verso_sentimento : "análise"
    topico ||--o{ verso_topico : "categoriza"

    versao {
        int id PK
        string sigla
        string nome
    }
    testamento {
        int id PK
        string nome
    }
    genero_literario {
        int id PK
        string nome
    }
    livro {
        int id PK
        string nome
        string abreviacao
        int testamento_id FK
        int genero_id FK
    }
    verso {
        int id PK
        int versao_id FK
        int livro_id FK
        int numero_capitulo
        int numero_verso
        string texto
    }
    verso_limpo {
        int verso_id PK, FK
        string texto_limpo
        real ratio_abstracao
        int n_conceitual
        int n_narrativo
        real propn_ratio
        string status_filtro 
    }
    topico {
        int id PK
        string antidoto_referencia
    }
    verso_topico {
        int verso_id PK, FK
        int topico_id FK
        float p_exaustao
        float p_transitoriedade
        float p_vazio
        float p_narrativo
        float similaridade_final
        float margem_dominancia
        string status_decisao
        float entropia
        float gap_confianca
    }
    verso_sentimento {
        int verso_id PK, FK
        string label
        int sentimento_num
        float score_pos
        float score_neg
        float score_neu
    }
