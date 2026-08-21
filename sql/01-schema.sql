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

CREATE TABLE IF NOT EXISTS "verso_limpo"(
    "verso_id" INTEGER PRIMARY KEY,
    "texto_limpo" TEXT NOT NULL,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- 3. CAMADA DE CLASSIFICAÇÃO EXISTENCIAL (Célula 5 - BERTopic)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "topico"(
    "id" INTEGER PRIMARY KEY,
    "antidoto_referencia" VARCHAR(100) NOT NULL -- Ex: Esgotamento (Han)
);

CREATE TABLE IF NOT EXISTS "verso_topico"(
    "verso_id" INTEGER PRIMARY KEY,
    "topico_id" INTEGER NOT NULL,
	"p_exaustao" FLOAT,
	"p_transitoriedade" FLOAT,
	"p_vazio" FLOAT,
	"p_narrativo" FLOAT,
    "similaridade_final" FLOAT,
	"margem_dominancia" FLOAT,
	"status_decisao" TEXT,
	"entropia" FLOAT,
	"gap_confianca" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (topico_id) REFERENCES topico(id)
);

-- 4. CAMADA RAG (Célula 5.1)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "rag_auditoria"(
    "verso_id" INTEGER PRIMARY KEY,
    "topico_id_anterior" INTEGER NOT NULL,
    "topico_id_novo" INTEGER NOT NULL,
	"justificativa" TEXT,
	"chunk_id" TEXT,
	"score_similaridade" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (topico_id_anterior) REFERENCES topico(id),
    FOREIGN KEY (topico_id_novo) REFERENCES topico(id)
);


-- 5. CAMADA DE ANÁLISE DE SENTIMENTO (Célula 6 - BERTimbau)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_sentimento"(
    "verso_id" INTEGER PRIMARY KEY,
    "label" VARCHAR(10) NOT NULL,       -- POS, NEU, NEG
    "sentimento_num" INTEGER NOT NULL, -- 1, 0, -1
    "score_pos" FLOAT,
    "score_neg" FLOAT,
    "score_neu" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- 6. ÍNDICES DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_livro_genero" ON "livro" ("genero_id");
CREATE INDEX IF NOT EXISTS "idx_verso_livro" ON "verso" ("livro_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_id" ON "verso_limpo" ("verso_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_id" ON "verso_topico" ("topico_id");
CREATE INDEX IF NOT EXISTS "idx_sentimento_label" ON "verso_sentimento" ("label");

-- 7. APOIO A INGESTAO DOS CHUNKS PARA O PROCESSAMENTO RAG
CREATE TABLE IF NOT EXISTS "chunks_comentario" (
	"chunk_id" TEXT PRIMARY KEY,
	"livro_id" INTEGER,
	"capitulo_inicio" INTEGER,
	"verso_inicio" INTEGER,
	"capitulo_fim" INTEGER,
	"verso_fim" INTEGER,
	"secao_n1" TEXT,
	"secao_n2" TEXT,
	"secao_n3" TEXT,
	"secao_n4" TEXT,
	"texto" TEXT,
	"pagina_origem" INTEGER,
	FOREIGN KEY (livro_id) REFERENCES livro(id)
);