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
erDiagram
    VERSAO ||--o{ VERSO : "contem"
    TESTAMENTO ||--o{ LIVRO : "agrupa"
    GENERO_LITERARIO ||--o{ LIVRO : "classifica"
    LIVRO ||--o{ VERSO : "contem"
    VERSO ||--|| VERSO_LIMPO : "pre-processado_em"
    VERSO ||--|| VERSO_TOPICO : "classificado_em"
    VERSO ||--|| VERSO_SENTIMENTO : "analisado_por"
    TOPICO ||--o{ VERSO_TOPICO : "define_eixo"

    VERSAO {
        int id PK
        string sigla
        string nome
    }
    TESTAMENTO {
        int id PK
        string nome
    }
    GENERO_LITERARIO {
        int id PK
        string nome
    }
    LIVRO {
        int id PK
        string nome
        string abreviacao
        int testamento_id FK
        int genero_id FK
    }
    VERSO {
        int id PK
        int versao_id FK
        int livro_id FK
        int numero_capitulo
        int numero_verso
        string texto
    }
    VERSO_LIMPO {
        int verso_id PK, FK
        string texto_limpo
    }
    TOPICO {
        int id PK
        string antidoto_referencia
    }
    VERSO_TOPICO {
        int verso_id PK, FK
        int topico_id FK
        float p_exaustao
        float p_transitoriedade
        float p_vazio
        float p_narrativo
        float similaridade_final
        float margem_dominancia
        text status_decisao
        float entropia
        float gap_confianca
    }
    VERSO_SENTIMENTO {
        int verso_id PK, FK
        string label
        int sentimento_num
        float score_pos
        float score_neg
        float score_neu
    }