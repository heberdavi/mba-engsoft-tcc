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
    "nome" VARCHAR(45) NOT NULL,
	"bonus_narrativo" REAL DEFAULT 0.0,
	"sensivel_ao_contexto" INTEGER DEFAULT 0
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
	"processar" CHAR(1) DEFAULT "S" NOT NULL,
    FOREIGN KEY (versao_id) REFERENCES versao(id),
    FOREIGN KEY (livro_id) REFERENCES livro(id)
);

CREATE TABLE IF NOT EXISTS "eixo" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "nome" TEXT NOT NULL UNIQUE,
    "cor_hex" TEXT -- Opcional: para facilitar visualizações gráficas futuras
);

CREATE TABLE IF NOT EXISTS "eixo_descricao" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "eixo_id" INTEGER,
    "sentenca" TEXT NOT NULL,
    FOREIGN KEY (eixo_id) REFERENCES eixo(id)
);

-- 2. CAMADA DE PROCESSAMENTO PLN (Célula 4)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_limpo"(
    "verso_id" INTEGER PRIMARY KEY,
    "texto_limpo" TEXT NOT NULL,
	"score_emocional" FLOAT, -- Densidade de ADJ + ADV (Indica potencial existencial)
	"score_informativo" FLOAT, -- Densidade de PROPN + NUM (Indica potencial de dados/ruído)
	"score_acao" FLOAT, -- Densidade de VERB (Indica potencial narrativo)
	"entropia_gramatical" FLOAT, -- Diversidade de classes gramaticais (Baixa entropia = texto repetitivo/lista)
	"n_primeira_pessoa" INTEGER, -- Contagem de quantos tokens no verso possuem a propriedade de 1ª pessoa no morfema do spaCy
	"avg_word_len" FLOAT, -- Soma do comprimento das palavras dividido pela quantidade de palavras significativas
	"is_identidade" INTEGER DEFAULT 0,
	"tem_numeral" INTEGER DEFAULT 0,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- Tabela de termos únicos (Dicionário)
CREATE TABLE IF NOT EXISTS "palavra" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "lemma" TEXT UNIQUE,
    "pos_tag" TEXT,
    "is_stop" INTEGER
);

-- Tabela de relacionamento (Índice Invertido)
-- Armazena onde a palavra aparece e qual era sua função ali
CREATE TABLE IF NOT EXISTS "verso_palavra" (
    "verso_id" INTEGER,
    "palavra_id" INTEGER,
	"posicao" INTEGER, -- A ordem da palavra no verso (t.i)
	"head_pos" INTEGER, -- A posicao do pai (t.head.i)
    "dep_relation" TEXT, -- Relação sintática (nsubj, obj, etc),
	"morph" TEXT, -- Gênero, Número, Tempo, Pessoa
    FOREIGN KEY (verso_id) REFERENCES verso(id),
    FOREIGN KEY (palavra_id) REFERENCES palavra(id)
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

-- 4. CAMADA DE ANÁLISE DE SENTIMENTO (Célula 6 - BERTimbau)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS "verso_sentimento"(
    "verso_id" INTEGER PRIMARY KEY,
    "label" VARCHAR(10) NOT NULL,       -- POS, NEU, NEG
    "sentimento_num" INTEGER NOT NULL, -- 1, 0, -1
    "score_pos" FLOAT,
    "score_neg" FLOAT,
    "score_neu" FLOAT,
	"sentimento_ajustado" FLOAT,
    FOREIGN KEY (verso_id) REFERENCES verso(id)
);

-- 5. ÍNDICES DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "idx_livro_genero" ON "livro" ("genero_id");
CREATE INDEX IF NOT EXISTS "idx_verso_livro" ON "verso" ("livro_id");
CREATE INDEX IF NOT EXISTS "idx_verso_limpo_id" ON "verso_limpo" ("verso_id");
CREATE INDEX IF NOT EXISTS "idx_verso_topico_id" ON "verso_topico" ("topico_id");
CREATE INDEX IF NOT EXISTS "idx_sentimento_label" ON "verso_sentimento" ("label");