# 📖 PLN Bíblia: Antídotos à Ansiedade Contemporânea

Este projeto de Trabalho de Conclusão de Curso (MBA em Engenharia de Software) utiliza técnicas de **Processamento de Linguagem Natural (PLN)** para analisar o texto bíblico (NVI) sob a ótica da psicologia existencial e sociologia contemporânea.

O objetivo é identificar "antídotos" nas escrituras para as angústias descritas por:
* **Viktor Frankl:** O vazio existencial e a busca de sentido.
* **Zygmunt Bauman:** A fragilidade dos laços e a incerteza da modernidade líquida.
* **Byung-Chul Han:** A exaustão e a fadiga na sociedade do desempenho.

---

## 🛠️ Arquitetura de Dados e Tecnologias

O projeto separa a estrutura de dados, o armazenamento e a lógica de processamento para garantir a integridade e escalabilidade da análise.

* **Banco de Dados:** SQLite (Relacional)
* **Linguagem:** Python 3.x
* **Modelos de IA:**
    * `BERTopic`: Para classificação Zero-Shot de eixos existenciais.
    * `BERTimbau (pysentimiento)`: Para análise de sentimento contextualizado em PT-BR.
    * `spaCy (pt_core_news_lg)`: Para limpeza estrutural e filtragem gramatical.

### 🗄️ Modelagem do Banco de Dados
A estrutura do banco de dados foi desenhada para suportar quatro camadas lógicas: Domínio Bíblico, Texto, Processamento PLN e Inteligência (Inference).

Para detalhes sobre as tabelas, tipos de dados e o **Diagrama de Entidade-Relacionamento (ER)** renderizado via Mermaid, acesse:
👉 **[Documentação da Arquitetura de Dados (database.md)](docs/database.md)**

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