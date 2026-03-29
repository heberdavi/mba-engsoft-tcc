erDiagram
    %% Camada de Estrutura Bíblica
    VERSAO ||--o{ VERSO : "contém"
    TESTAMENTO ||--o{ LIVRO : "agrupa"
    GENERO_LITERARIO ||--o{ LIVRO : "classifica"
    LIVRO ||--o{ VERSO : "contém"

    %% Camada de Inteligência e PLN
    VERSO ||--|| VERSO_LIMPO : "pré-processado em"
    VERSO ||--|| VERSO_TOPICO : "classificado em"
    VERSO ||--|| VERSO_SENTIMENTO : "analisado por"
    TOPICO ||--o{ VERSO_TOPICO : "define eixo"

    VERSAO {
        int id PK
        string sigla "VARCHAR(10)"
        string nome "VARCHAR(50)"
    }

    TESTAMENTO {
        int id PK
        string nome "VARCHAR(45)"
    }

    GENERO_LITERARIO {
        int id PK
        string nome "VARCHAR(45)"
    }

    LIVRO {
        int id PK
        string nome "VARCHAR(45)"
        string abreviacao "VARCHAR(5)"
        int testamento_id FK
        int genero_id FK
    }

    VERSO {
        int id PK
        int versao_id FK
        int livro_id FK
        int numero_capitulo
        int numero_verso
        string texto "TEXT"
    }

    VERSO_LIMPO {
        int verso_id PK, FK
        string texto_limpo "TEXT"
    }

    TOPICO {
        int id PK
        string antidoto_referencia "VARCHAR(100)"
    }

    VERSO_TOPICO {
        int verso_id PK, FK
        int topico_id FK
        float similaridade
    }

    VERSO_SENTIMENTO {
        int verso_id PK, FK
        string label "VARCHAR(10)"
        int sentimento_num "INTEGER"
        float score_pos
        float score_neg
        float score_neu
    }