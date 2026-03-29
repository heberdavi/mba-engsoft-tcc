-- =============================================================================
-- ARTEFATO: 01-schema.sql
-- PROJETO: TCC MBA Engenharia de Software - PLN Bíblia vs. Ansiedade Contemporânea
-- =============================================================================

-- 1. ESTRUTURA BÁSICA (Textos Bíblicos conforme original NVI)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS "verso";
DROP TABLE IF EXISTS "livro";
DROP TABLE IF EXISTS "genero_literario";
DROP TABLE IF EXISTS "testamento";
DROP TABLE IF EXISTS "versao";

CREATE TABLE "versao"(
    "id" INTEGER PRIMARY KEY,
    "sigla" VARCHAR(10) NOT NULL,
    "nome" VARCHAR(50) NOT NULL
);

CREATE TABLE "testamento"(
    "id" INTEGER PRIMARY KEY,
    "nome" VARCHAR(45) NOT NULL
);

CREATE TABLE "genero_literario"(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "nome" VARCHAR(45) NOT NULL
);

CREATE TABLE "livro"(
    "id" INTEGER PRIMARY KEY,
    "nome" VARCHAR(45) NOT NULL,
    "abreviacao" VARCHAR(5) NOT NULL,
    "testamento_id" INTEGER NOT NULL,
    "genero_id" INTEGER NOT NULL,
    FOREIGN KEY (testamento_id) REFERENCES testamento(id),
    FOREIGN KEY (genero_id) REFERENCES genero_literario(id)
);

CREATE TABLE "verso"(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "versao_id" INTEGER NOT NULL,
    "livro_id" INTEGER NOT NULL,
    "numero_capitulo" INTEGER NOT NULL,
    "numero_verso" INTEGER NOT NULL,
    "texto" TEXT NOT NULL,
    FOREIGN KEY (versao_id) REFERENCES versao(id),
    FOREIGN KEY (livro_id) REFERENCES livro(id)
);

-- 2. CAMADA DE PROCESSAMENTO PLN (Célula 4)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS "verso_limpo";
CREATE TABLE "verso_limpo"(
    "verso_id" INTEGER PRIMARY KEY,
    "texto_limpo" TEXT NOT NULL,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- 3. CAMADA DE CLASSIFICAÇÃO EXISTENCIAL (Célula 5 - BERTopic)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS "verso_topico";
DROP TABLE IF EXISTS "topico";

CREATE TABLE "topico"(
    "id" INTEGER PRIMARY KEY,
    "antidoto_referencia" VARCHAR(100) NOT NULL -- Ex: Esgotamento (Han)
);

CREATE TABLE "verso_topico"(
    "verso_id" INTEGER PRIMARY KEY,
    "topico_id" INTEGER NOT NULL,
    "similaridade" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (topico_id) REFERENCES topico(id)
);

-- 4. CAMADA DE ANÁLISE DE SENTIMENTO (Célula 6 - BERTimbau)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS "verso_sentimento";
CREATE TABLE "verso_sentimento"(
    "verso_id" INTEGER PRIMARY KEY,
    "label" VARCHAR(10) NOT NULL,       -- POS, NEU, NEG
    "sentimento_num" INTEGER NOT NULL, -- 1, 0, -1
    "score_pos" FLOAT,
    "score_neg" FLOAT,
    "score_neu" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- 5. ÍNDICES DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_livro_genero" ON "livro" ("genero_id");
CREATE INDEX IF NOT EXISTS "idx_verso_livro" ON "verso" ("livro_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_id" ON "verso_limpo" ("verso_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_id" ON "verso_topico" ("topico_id");
CREATE INDEX IF NOT EXISTS "idx_sentimento_label" ON "verso_sentimento" ("label");