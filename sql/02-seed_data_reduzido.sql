-- =============================================================================
-- ARTEFATO: 02-seed_data.sql
-- FINALIDADE: População inicial do banco (Dados Mestres e Texto Bíblico NVI)
-- ORDEM DE EXECUÇÃO: 2º (Deve ser executado após o 01-schema.sql)
-- =============================================================================

-- 1. População das Tabelas de Referência
-- -----------------------------------------------------------------------------

INSERT INTO versao(id, sigla, nome) VALUES (1, 'NVI', 'Nova Versão Internacional');

INSERT INTO testamento(id, nome) VALUES (1, 'Velho Testamento'), (2, 'Novo Testamento');

INSERT INTO genero_literario (id, nome) VALUES 
(1, 'Pentateuco'),
(2, 'Histórico'),
(3, 'Poético/Sapiencial'),
(4, 'Profético'),
(5, 'Evangelho'),
(6, 'Epístola'),
(7, 'Apocalíptico');

-- 2. População da Tabela de Livros
-- -----------------------------------------------------------------------------

INSERT INTO livro(id, nome, abreviacao, testamento_id, genero_id) VALUES 
(1,'Gênesis','Gn',1,1), (2,'Êxodo','Êx',1,1), (3,'Levítico','Lv',1,1), (4,'Números','Nm',1,1), (5,'Deuteronômio','Dt',1,1),
(6,'Josué','Js',1,2), (7,'Juízes','Jz',1,2), (8,'Rute','Rt',1,2), (9,'1 Samuel','1Sm',1,2), (10,'2 Samuel','2Sm',1,2),
(11,'1 Reis','1Rs',1,2), (12,'2 Reis','2Rs',1,2), (13,'1 Crônicas','1Cr',1,2), (14,'2 Crônicas','2Cr',1,2), (15,'Esdras','Ed',1,2),
(16,'Neemias','Ne',1,2), (17,'Ester','Et',1,2), (18,'Jó','Jó',1,3), (19,'Salmos','Sl',1,3), (20,'Provérbios','Pv',1,3),
(21,'Eclesiastes','Ec',1,3), (22,'Cânticos','Ct',1,3), (23,'Isaías','Is',1,4), (24,'Jeremias','Jr',1,4), (25,'Lamentações','Lm',1,4),
(26,'Ezequiel','Ez',1,4), (27,'Daniel','Dn',1,4), (28,'Oseias','Os',1,4), (29,'Joel','Jl',1,4), (30,'Amós','Am',1,4),
(31,'Obadias','Ob',1,4), (32,'Jonas','Jon',1,4), (33,'Miqueias','Mq',1,4), (34,'Naum','Na',1,4), (35,'Habacuque','Hc',1,4),
(36,'Sofonias','Sf',1,4), (37,'Ageu','Ag',1,4), (38,'Zacarias','Zc',1,4), (39,'Malaquias','Ml',1,4), (40,'Mateus','Mt',2,5),
(41,'Marcos','Mc',2,5), (42,'Lucas','Lc',2,5), (43,'João','Jo',2,5), (44,'Atos','At',2,2), (45,'Romanos','Rm',2,6),
(46,'1 Coríntios','1Co',2,6), (47,'2 Coríntios','2Co',2,6), (48,'Gálatas','Gl',2,6), (49,'Efésios','Ef',2,6), (50,'Filipenses','Fp',2,6),
(51,'Colossenses','Cl',2,6), (52,'1 Tessalonicenses','1Ts',2,6), (53,'2 Tessalonicenses','2Ts',2,6), (54,'1 Timóteo','1Tm',2,6), (55,'2 Timóteo','2Tm',2,6),
(56,'Tito','Tt',2,6), (57,'Filemom','Fm',2,6), (58,'Hebreus','Hb',2,6), (59,'Tiago','Tg',2,6), (60,'1 Pedro','1Pe',2,6),
(61,'2 Pedro','2Pe',2,6), (62,'1 João','1Jo',2,6), (63,'2 João','2Jo',2,6), (64,'3 João','3Jo',2,6), (65,'Judas','Jd',2,6), (66,'Apocalipse','Ap',2,7);

-- 3. População da Tabela de Versos (Texto Integral)
-- -----------------------------------------------------------------------------

INSERT INTO verso(versao_id, livro_id, numero_capitulo, numero_verso, texto) VALUES (1, 19, 18, 2, "O Senhor é a minha rocha, a minha fortaleza e o meu libertador; o meu Deus é o meu rochedo, em quem me refugio. Ele é o meu escudo e o poder que me salva, a minha torre alta."),
(2, 19, 23, 3, "restaura-me o vigor. Guia-me nas veredas da justiça por amor do seu nome."), (3, 19, 42, 1, "Como a corça anseia por águas correntes, a minha alma anseia por ti, ó Deus."), (4, 19, 62, 1, "A minha alma descansa somente em Deus; dele vem a minha salvação."), 
(5, 19, 102, 11, "Meus dias são como sombras crescentes; sou como a relva que vai murchando."), (6, 21, 1, 2, "Que grande inutilidade! , diz o Mestre. Que grande inutilidade! Nada faz sentido! "), (7, 21, 2, 11, "Contudo, quando avaliei tudo o que as minhas mãos haviam feito e o trabalho que eu tanto me esforçara para realizar, percebi que tudo foi inútil, foi correr atrás do vento; não há qualquer proveito no que se faz debaixo do sol."), (8, 23, 40, 8, "A relva murcha, e as flores caem, mas a palavra de nosso Deus permanece para sempre. "), 
(9, 23, 40, 29, "Ele fortalece ao cansado e dá grande vigor ao que está sem forças."), (10, 23, 43, 1, "Mas agora assim diz o Senhor, aquele que o criou, ó Jacó, aquele que o formou, ó Israel: Não tema, pois eu o resgatei; eu o chamei pelo nome; você é meu."), (11, 24, 29, 11, "Porque sou eu que conheço os planos que tenho para vocês, diz o Senhor, planos de fazê-los prosperar e não de lhes causar dano, planos de dar-lhes esperança e um futuro."), (12, 40, 7, 24, "Portanto, quem ouve estas minhas palavras e as pratica é como um homem prudente que construiu a sua casa sobre a rocha."), (13, 40, 11, 28, "Venham a mim, todos os que estão cansados e sobrecarregados, e eu lhes darei descanso."), (14, 49, 2, 10, "Porque somos criação de Deus realizada em Cristo Jesus para fazermos boas obras, as quais Deus preparou de antemão para que nós as praticássemos."), (15, 59, 4, 14, "Vocês nem sabem o que lhes acontecerá amanhã! Que é a sua vida? Vocês são como a neblina que aparece por um pouco de tempo e depois se dissipa.");