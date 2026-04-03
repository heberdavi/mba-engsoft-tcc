-- total de versos por eixo filosófico
-- total de versos com sentimento positivo, considerados como "Antidotos_Cura" 
-- total de versos com sentimento negativo, considerados como "Problematica_Crise"
-- polaridade média
SELECT
	t.antidoto_referencia as Eixo_Filosofico,
	COUNT(*) as Total_Versos,
	SUM(CASE WHEN vs.sentimento_num = 1 THEN 1 ELSE 0 END) as Antidotos_Cura,
	SUM(CASE WHEN vs.sentimento_num = -1 THEN 1 ELSE 0 END) as Problematica_Crise,
	ROUND(AVG(vs.sentimento_num), 3) as Polaridade_Media
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
WHERE t.id != 3 -- Foco nos eixos Han, Bauman e Frankl
GROUP BY t.antidoto_referencia
ORDER BY Polaridade_Media DESC;

-- distribuicao de antidotos, por genero literario
SELECT
	g.nome as Genero,
	t.antidoto_referencia as Antidoto,
	COUNT(vt.verso_id) as Frequencia
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
JOIN verso v ON vt.verso_id = v.id
JOIN livro l ON v.livro_id = l.id
JOIN genero_literario g ON l.genero_id = g.id
WHERE vs.sentimento_num = 1  -- FILTRO: Apenas a Cura (Positivo)
  AND t.id != 3              -- Exclui Narrativo/Outros
GROUP BY Genero, Antidoto;


-- saldo resolutividade (gauge)
SELECT
	t.id,
	t.antidoto_referencia,
	CAST(SUM(CASE WHEN vs.sentimento_num = 1 THEN 1 ELSE 0 END) -
		 SUM(CASE WHEN vs.sentimento_num = -1 THEN 1 ELSE 0 END) AS FLOAT) /
		 COUNT(vs.verso_id) as saldo_resolutividade
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
WHERE t.id IN (0, 1, 2)
GROUP BY t.id, t.antidoto_referencia;

-- crise x cura, por gênero literário
SELECT
	g.nome as Genero,
	SUM(CASE WHEN vs.sentimento_num = 1 THEN 1 ELSE 0 END) as Cura_Positivo,
	SUM(CASE WHEN vs.sentimento_num = -1 THEN 1 ELSE 0 END) as Crise_Negativo
FROM genero_literario g
JOIN livro l ON g.id = l.genero_id
JOIN verso v ON l.id = v.livro_id
JOIN verso_topico vt ON v.id = vt.verso_id
JOIN verso_sentimento vs ON v.id = vs.verso_id
WHERE vt.topico_id IN (0, 1, 2)
GROUP BY g.nome
HAVING (Cura_Positivo + Crise_Negativo) > 0
ORDER BY (Cura_Positivo + Crise_Negativo) DESC;

-- média de sentimento, por genero  e autor
SELECT
	g.nome as Genero,
	t.antidoto_referencia as Autor,
	CAST(SUM(CASE WHEN vs.sentimento_num = 1 THEN 1 ELSE 0 END) -
		 SUM(CASE WHEN vs.sentimento_num = -1 THEN 1 ELSE 0 END) AS FLOAT) /
		 COUNT(vs.verso_id) as Saldo
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
JOIN verso v ON vt.verso_id = v.id
JOIN livro l ON v.livro_id = l.id
JOIN genero_literario g ON l.genero_id = g.id
WHERE t.id IN (0, 1, 2)
GROUP BY Genero, Autor
HAVING COUNT(vs.verso_id) > 10;

-- distribuicao da densidade emocional (violin) - não utilizado
SELECT
	t.antidoto_referencia as Autor,
	vs.sentimento_num as Sentimento
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
WHERE t.id IN (0, 1, 2);

-- amplitude e média de sentimento, por gênero
SELECT 
	g.nome as Genero,
	CASE 
		WHEN vs.sentimento_num = 1 THEN vs.score_pos
		WHEN vs.sentimento_num = -1 THEN -vs.score_neg
		ELSE 0 
	END as Polaridade_Real
FROM verso_topico vt
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
JOIN verso v ON vt.verso_id = v.id
JOIN livro l ON v.livro_id = l.id
JOIN genero_literario g ON l.genero_id = g.id
WHERE vt.topico_id IN (0, 1, 2);