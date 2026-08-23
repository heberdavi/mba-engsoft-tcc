-- =============================================================================
-- ARTEFATO: 01-schema.sql
-- =============================================================================

-- 1. ESTRUTURA BÁSICA (Textos Bíblicos)
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
    "id" INTEGER PRIMARY KEY,
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

-- 2. CAMADA DE CLASSIFICAÇÃO EXISTENCIAL (Célula 5 - BERTopic)
-- -----------------------------------------------------------------------------

-- Tabela de Tópicos/Eixos Existenciais
CREATE TABLE IF NOT EXISTS "topico"(
    "id" INTEGER PRIMARY KEY,
    "nome_curto" VARCHAR(100) NOT NULL,
	"antidoto_referencia" VARCHAR(100) NOT NULL,
    "autores_referencia" VARCHAR(200),
    "descricao_ancora_zeroshot" TEXT NOT NULL,
    "descricao_prompt_llm" TEXT NOT NULL,
    "eh_categoria_residual" BOOLEAN DEFAULT 0,
    "framework_versao_id" INTEGER NOT NULL,
	FOREIGN KEY (framework_versao_id) REFERENCES framework_versao(id)
);

-- 3. CAMADA DE CONTROLE DE PROCESSAMENTO DO PIPELINE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "framework_versao" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "codigo_versao" VARCHAR(20) NOT NULL UNIQUE,
    "data_criacao" TEXT NOT NULL,
    "descricao_mudancas" TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS "execucao_pipeline" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "data_execucao" TEXT NOT NULL,
    "modelo_embeddings_topico" VARCHAR(100),
    "modelo_embeddings_rag" VARCHAR(100),
    "modelo_llm_arbitragem" VARCHAR(100),
    "framework_versao_id" INTEGER NOT NULL,
    "observacoes" TEXT,
	FOREIGN KEY (framework_versao_id) REFERENCES framework_versao(id)
);

-- 4. CAMADA DE PROCESSAMENTO PLN (Células 4, 5 e 5.1)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_limpo"(
    "verso_id" INTEGER NOT NULL,
    "execucao_id" INTEGER NOT NULL,
    "texto_limpo" TEXT NOT NULL,
	PRIMARY KEY (verso_id, execucao_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_id) REFERENCES execucao_pipeline(id)
);

-- Tabela de Decisão Final por Versículo (Metadados globais da classificação)
CREATE TABLE IF NOT EXISTS "verso_topico"(
    "verso_id" INTEGER NOT NULL,
    "execucao_id" INTEGER NOT NULL,
    "topico_id" INTEGER NOT NULL, -- Eixo dominante
    "status_decisao" TEXT,
    "entropia" FLOAT,
    "gap_confianca" FLOAT,
    "margem_dominancia" FLOAT,
    PRIMARY KEY (verso_id, execucao_id),
	FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (topico_id) REFERENCES topico(id),
    FOREIGN KEY (execucao_id) REFERENCES execucao_pipeline(id)
);

-- Tabela Longa de Probabilidades por Eixo (Normalização)
CREATE TABLE IF NOT EXISTS "verso_topico_probabilidade" (
    "verso_id" INTEGER NOT NULL,
    "execucao_id" INTEGER NOT NULL,
    "topico_id" INTEGER NOT NULL,
    "probabilidade" FLOAT NOT NULL,
	PRIMARY KEY (verso_id, execucao_id, topico_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_id) REFERENCES execucao_pipeline(id),
    FOREIGN KEY (topico_id) REFERENCES topico(id)
);

-- 5. CAMADA RAG (Célula 5.1)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_auditoria_rag"(
    "verso_id" INTEGER NOT NULL,
    "execucao_id" INTEGER NOT NULL,
    "topico_id_anterior" INTEGER NOT NULL,
    "topico_id_novo" INTEGER NOT NULL,
	"justificativa" TEXT,
	"chunk_id" TEXT,
	"score_similaridade" FLOAT,
	PRIMARY KEY (verso_id, execucao_id),
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_id) REFERENCES execucao_pipeline(id),
    FOREIGN KEY (topico_id_anterior) REFERENCES topico(id),
    FOREIGN KEY (topico_id_novo) REFERENCES topico(id)
);


-- 6. CAMADA DE ANÁLISE DE SENTIMENTO (Célula 6 - BERTimbau)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_sentimento"(
    "verso_id" INTEGER NOT NULL,
    "execucao_id" INTEGER NOT NULL,
    "label" VARCHAR(10) NOT NULL, -- POS, NEU, NEG
    "sentimento_num" INTEGER NOT NULL, -- 1, 0, -1
    "score_pos" FLOAT,
    "score_neg" FLOAT,
    "score_neu" FLOAT,
    PRIMARY KEY (verso_id, execucao_id),
	FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (execucao_id) REFERENCES execucao_pipeline(id)
);

-- 7. ÍNDICES DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_livro_genero" ON "livro" ("genero_id");
CREATE INDEX IF NOT EXISTS "idx_verso_livro" ON "verso" ("livro_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_id" ON "verso_limpo" ("verso_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_id" ON "verso_topico" ("topico_id");
CREATE INDEX IF NOT EXISTS "idx_sentimento_label" ON "verso_sentimento" ("label");

-- 8. APOIO A INGESTAO DOS CHUNKS PARA O PROCESSAMENTO RAG
-- -----------------------------------------------------------------------------
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