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

