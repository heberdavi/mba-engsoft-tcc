-- =============================================================================
-- ARTEFATO: 01-schema.sql
-- PROJETO: TCC MBA Engenharia de Software
-- =============================================================================

-- 1. ESTRUTURA BÁSICA (Textos Bíblicos conforme original NVI)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "versao"(
    "id" INTEGER PRIMARY KEY,
    "sigla" VARCHAR(10) NOT NULL,
    "nome" VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS "testamento"(
    "id" INTEGER PRIMARY KEY,
    "nome" VARCHAR(45) NOT NULL
);

CREATE TABLE IF NOT EXISTS "genero_literario"(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "nome" VARCHAR(45) NOT NULL
);

CREATE TABLE IF NOT EXISTS "livro"(
    "id" INTEGER PRIMARY KEY,
    "nome" VARCHAR(45) NOT NULL,
    "abreviacao" VARCHAR(5) NOT NULL,
    "testamento_id" INTEGER NOT NULL,
    "genero_id" INTEGER NOT NULL,
    FOREIGN KEY (testamento_id) REFERENCES testamento(id),
    FOREIGN KEY (genero_id) REFERENCES genero_literario(id)
);

CREATE TABLE IF NOT EXISTS "verso"(
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

CREATE TABLE IF NOT EXISTS execucao_pipeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_execucao DATETIME DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT
);

CREATE TABLE IF NOT EXISTS "verso_limpo"(
    "verso_id" INTEGER NOT NULL,
	"execucao_pipeline_id" INTEGER NOT NULL,
    "texto_limpo" TEXT NOT NULL,
	PRIMARY KEY (verso_id, execucao_pipeline_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_pipeline_id) REFERENCES execucao_pipeline(id)
);

-- 3. CAMADA DE CLASSIFICAÇÃO EXISTENCIAL (Célula 5 - Zero-Shot Classification)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "topico"(
    "id" INTEGER PRIMARY KEY,
    "nome" VARCHAR(100) NOT NULL, -- Ex: Esgotamento (Han)
	"eh_descarte" BOOLEAN NOT NULL DEFAULT 0 -- 1 para Narrativo/Normativo, 0 para os demais
);

CREATE TABLE IF NOT EXISTS "topico_descricao"(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "topico_id" INTEGER NOT NULL,
    "descricao" TEXT,
	"data_criacao" DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (topico_id) REFERENCES topico(id)
);

CREATE TABLE IF NOT EXISTS "verso_topico"(
    "verso_id" INTEGER NOT NULL,
    "execucao_pipeline_id" INTEGER NOT NULL,
	"topico_descricao_id" INTEGER NOT NULL,
    "similaridade_final" FLOAT,
	"margem_dominancia" FLOAT,
	"status_decisao" TEXT,
	"entropia" FLOAT,
	"gap_confianca" FLOAT,
	PRIMARY KEY (verso_id, execucao_pipeline_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_pipeline_id) REFERENCES execucao_pipeline(id),
    FOREIGN KEY (topico_descricao_id) REFERENCES topico_descricao(id)
);

CREATE TABLE IF NOT EXISTS "verso_topico_probabilidade"(
    "verso_id" INTEGER NOT NULL,
    "execucao_pipeline_id" INTEGER NOT NULL,
    "topico_descricao_id" INTEGER NOT NULL,
    "probabilidade" FLOAT NOT NULL,
    PRIMARY KEY (verso_id, execucao_pipeline_id, topico_descricao_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_pipeline_id) REFERENCES execucao_pipeline(id),
    FOREIGN KEY (topico_descricao_id) REFERENCES topico_descricao(id)
);

-- 4. CAMADA DE ANÁLISE DE SENTIMENTO (Célula 6 - BERTimbau)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_sentimento"(
    "verso_id" INTEGER NOT NULL,
	"execucao_pipeline_id" INTEGER NOT NULL,
    "label" VARCHAR(10) NOT NULL,       -- POS, NEU, NEG
    "sentimento_num" INTEGER NOT NULL, -- 1, 0, -1
    "score_pos" FLOAT,
    "score_neg" FLOAT,
    "score_neu" FLOAT,
	PRIMARY KEY (verso_id, execucao_pipeline_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_pipeline_id) REFERENCES execucao_pipeline(id)
);

-- 5. ÍNDICES DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_livro_genero" ON "livro" ("genero_id");
CREATE INDEX IF NOT EXISTS "idx_verso_livro" ON "verso" ("livro_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_id" ON "verso_limpo" ("verso_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_exec" ON "verso_limpo" ("execucao_pipeline_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_id" ON "verso_topico" ("topico_descricao_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_exec" ON "verso_topico" ("execucao_pipeline_id");
CREATE INDEX IF NOT EXISTS "idx_sentimento_label" ON "verso_sentimento" ("label");
CREATE INDEX IF NOT EXISTS "idx_sentimento_exec" ON "verso_sentimento" ("execucao_pipeline_id");

-- 6. VISOES
-- -----------------------------------------------------------------------------
-- VIEW para automatizar o carregamento da versão vigente no Python
CREATE VIEW IF NOT EXISTS v_topico_descricao_vigente AS
SELECT 
    td.id AS topico_descricao_id, 
    td.topico_id, 
    t.nome AS topico_nome, 
    td.descricao
FROM topico_descricao td
JOIN topico t ON t.id = td.topico_id
WHERE td.id IN (
    SELECT MAX(id)
    FROM topico_descricao
    GROUP BY topico_id
);