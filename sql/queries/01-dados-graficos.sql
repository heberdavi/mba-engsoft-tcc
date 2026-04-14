-- total de antidotos, independentemente de livro ou gênero literário
-- exclui o eixo narrativo / normativo
select count(1) total_antidotos
from verso_sentimento vs
inner join verso_topico vt on vt.verso_id = vs.verso_id
inner join topico t on t.id = vt.topico_id
where vs.label = 'POS'
and t.antidoto_referencia <> 'Narrativo/Normativo';

-- total de antidotos, independentemente de livro ou gênero literário, por eixo
-- exclui o eixo narrativo / normativo
select t.antidoto_referencia, count(1) total_antidotos
from verso_sentimento vs
inner join verso_topico vt on vt.verso_id = vs.verso_id
inner join topico t on t.id = vt.topico_id
where vs.label = 'POS'
and t.antidoto_referencia <> 'Narrativo/Normativo'
group by t.antidoto_referencia
order by total_antidotos desc;

-- analise da eficiencia semantica, por eixo pesquisado
-- desconsidera o eixo Narrativo / Normativo
SELECT 
    t.antidoto_referencia AS "Eixo Existencial",
    COUNT(vt.verso_id) AS "Total de Versos no Eixo",
    SUM(CASE WHEN vs.label = 'POS' THEN 1 ELSE 0 END) AS "Versos com Sentimento Positivo",
    ROUND(
        CAST(SUM(CASE WHEN vs.label = 'POS' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(vt.verso_id) * 100, 2
    ) || '%' AS "Eficiência de Cura (%)"
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
WHERE vt.topico_id < 3 -- Considera apenas os eixos: Exaustão, Transitoriedade e Vazio
GROUP BY t.id, t.antidoto_referencia
ORDER BY CAST(SUM(CASE WHEN vs.label = 'POS' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(vt.verso_id) DESC;


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

-- nuvem de palavras
-- ocorrências de antídotos (sentimento positivo) 
-- relacionadas ao eixo Transitoriedade vs. Solidez
-- e gênero literário 'Poético/Sapiencial'
SELECT vl.texto_limpo
FROM verso v
JOIN livro l ON l.id = v.livro_id
JOIN genero_literario gl ON gl.id = l.genero_id
JOIN verso_topico vt ON vt.verso_id = v.id
JOIN topico t ON t.id = vt.topico_id
JOIN verso_sentimento vs ON vs.verso_id = v.id
JOIN verso_limpo vl ON vl.verso_id = v.id
WHERE gl.nome = 'Poético/Sapiencial'
AND t.antidoto_referencia = 'Transitoriedade vs. Solidez'
AND vs.label = 'POS';

-- exemplos de versos que contém algumas dss principais palavras identificadas na nuvem: 
-- maravilhas, fidelidade, justiça
SELECT l.abreviacao, v.numero_capitulo||':'||v.numero_verso ref, 
	v.texto, vs.score_pos
FROM verso v
JOIN livro l ON l.id = v.livro_id
JOIN genero_literario gl ON gl.id = l.genero_id
JOIN verso_topico vt ON vt.verso_id = v.id
JOIN topico t ON t.id = vt.topico_id
JOIN verso_sentimento vs ON vs.verso_id = v.id
JOIN verso_limpo vl ON vl.verso_id = v.id
WHERE gl.nome = 'Poético/Sapiencial'
AND t.antidoto_referencia = 'Transitoriedade vs. Solidez'
AND vs.label = 'POS'
AND ((lower(texto_limpo) like '%maravilhas%') OR
	 (lower(texto_limpo) like '%fidelidade%') OR
	 (lower(texto_limpo) like '%justiça%'))
ORDER BY vs.score_pos DESC;

-- versos do gênero Profético
-- vinculados ao eixo Vazio vs. Propósito
-- definidos como antídotos (sentimento POSitivo)
-- ordenados por escore de positividade
-- apresentando o gap de confiança
SELECT l.abreviacao||' '||v.numero_capitulo||':'||v.numero_verso AS Ref,
	v.texto, vs.score_pos AS Score, vt.gap_confianca AS Gap
	, vt.p_exaustao, vt.p_transitoriedade, vt.p_vazio, vt.p_narrativo
	, vt.p_narrativo - vt.p_vazio calc_mrg_dmn, vt.margem_dominancia
FROM genero_literario gl
JOIN livro l ON l.genero_id = gl.id
JOIN verso v ON v.livro_id = l.id
JOIN verso_topico vt ON vt.verso_id = v.id
JOIN topico t ON t.id = vt.topico_id
JOIN verso_sentimento vs ON vs.verso_id = v.id
WHERE gl.nome = 'Profético'
AND t.antidoto_referencia = 'Vazio vs. Propósito'
AND vs.label = 'POS'
ORDER BY Score DESC
--ORDER BY Gap DESC
;

-- avaliação específica de Is 50:4
select v.texto, vl.texto_limpo,
	vs.label, vs.score_pos, vs.score_neg, vs.score_neu,
	t.antidoto_referencia, vt.*
from livro l
join verso v on v.livro_id = l.id
join verso_limpo vl on vl.verso_id = v.id
join verso_sentimento vs on vs.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where l.abreviacao = 'Is'
and v.numero_capitulo = 50
and v.numero_verso = 4;

-- versos com sentimento positivo com sentimento POS, 
-- que foram puxados para um eixo que não o Narrativo/Normativo,
-- mesmo que o escore desse eixo tenha sido maior
select gl.nome genero, t.antidoto_referencia, 
	l.abreviacao||' '||v.numero_capitulo||':'||v.numero_verso ref, v.texto,
	vt.similaridade_final, vt.p_narrativo, vt.margem_dominancia, 
	vt.status_decisao, vt.entropia, vt.gap_confianca
from verso v
join livro l on l.id = v.livro_id
join genero_literario gl on gl.id = l.genero_id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
join verso_sentimento vs on vs.verso_id = v.id
where vt.similaridade_final < vt.p_narrativo
and vs.label = 'POS';

-- agrupando por gênero
select gl.nome genero, count(1) qt_ocor
from verso v
join livro l on l.id = v.livro_id
join genero_literario gl on gl.id = l.genero_id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
join verso_sentimento vs on vs.verso_id = v.id
where vt.similaridade_final < vt.p_narrativo
and vs.label = 'POS'
group by genero;

-- agrupando por eixo
select t.antidoto_referencia eixo, count(1) qt_ocor
from verso v
join livro l on l.id = v.livro_id
join genero_literario gl on gl.id = l.genero_id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
join verso_sentimento vs on vs.verso_id = v.id
where vt.similaridade_final < vt.p_narrativo
and vs.label = 'POS'
group by eixo;

-- agrupando por gênero e eixo
select gl.nome genero, t.antidoto_referencia eixo, count(1) qt_ocor
from verso v
join livro l on l.id = v.livro_id
join genero_literario gl on gl.id = l.genero_id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
join verso_sentimento vs on vs.verso_id = v.id
where vt.similaridade_final < vt.p_narrativo
and vs.label = 'POS'
group by genero, eixo
order by genero, qt_ocor desc;

-- quais versos de determinado gênero e eixo foram puxados?
select gl.nome genero, t.antidoto_referencia, 
	l.abreviacao||' '||v.numero_capitulo||':'||v.numero_verso ref, v.texto,
	vt.similaridade_final, vt.p_narrativo, vt.margem_dominancia, 
	vt.status_decisao, vt.entropia, vt.gap_confianca
from verso v
join livro l on l.id = v.livro_id
join genero_literario gl on gl.id = l.genero_id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
join verso_sentimento vs on vs.verso_id = v.id
where vt.similaridade_final < vt.p_narrativo
and gl.nome = 'Evangelho'
and t.antidoto_referencia = 'Transitoriedade vs. Solidez'
and vs.label = 'POS';

-- amplitude emocional, por gênero
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

-- maior scores positivo e negativo
-- polaridade média
-- por gênero
SELECT 
    gl.nome AS genero,
    ROUND(MAX(vs.score_pos), 4) AS maior_score_positivo,
    ROUND(MAX(vs.score_neg), 4) AS maior_score_negativo,
    ROUND(AVG(CASE 
        WHEN vs.label = 'POS' THEN vs.score_pos 
        WHEN vs.label = 'NEG' THEN -vs.score_neg 
        ELSE 0 
    END), 4) AS polaridade_media
FROM genero_literario gl
JOIN livro l ON l.genero_id = gl.id
JOIN verso v ON v.livro_id = l.id
JOIN verso_sentimento vs ON vs.verso_id = v.id
GROUP BY gl.nome
ORDER BY polaridade_media DESC;

-- média de positividade dos antídotos
select t.antidoto_referencia, avg(vs.score_pos) media_positividade
from topico t
join verso_topico vt on vt.topico_id = t.id
join verso_sentimento vs on vs.verso_id = vt.verso_id
where t.id <> 3
and vs.label = 'POS'
group by t.antidoto_referencia
order by media_positividade desc;

-- limitações do modelo
select l.abreviacao||' '||v.numero_capitulo||':'||v.numero_verso as Ref,
	v.texto, vl.texto_limpo, 
	vs.label, t.antidoto_referencia,
	vt.similaridade_final, vt.p_exaustao, vt.p_transitoriedade, vt.p_vazio, vt.p_narrativo,
	vt.margem_dominancia, vt.status_decisao, vt.entropia, vt.gap_confianca
from verso v
join livro l on l.id = v.livro_id
join verso_limpo vl on vl.verso_id = v.id
join verso_sentimento vs on vs.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where lower(v.texto) like '%meu pastor%';

select l.abreviacao||' '||v.numero_capitulo||':'||v.numero_verso as Ref,
	v.texto, vl.texto_limpo, 
	vs.label, t.antidoto_referencia,
	vt.similaridade_final, vt.p_exaustao, vt.p_transitoriedade, vt.p_vazio, vt.p_narrativo,
	vt.margem_dominancia, vt.status_decisao, vt.entropia, vt.gap_confianca
from verso v
join livro l on l.id = v.livro_id
join verso_limpo vl on vl.verso_id = v.id
join verso_sentimento vs on vs.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where l.abreviacao = 'At'
and v.numero_capitulo = 2
and v.numero_verso = 28;

-- buscando outros versos teologicamente fortes, mas que foram descartados
SELECT 
    l.abreviacao || ' ' || v.numero_capitulo || ':' || v.numero_verso AS ref,
    v.texto,
    vt.status_decisao,
    vt.entropia,
    vt.p_exaustao, 
    vt.p_transitoriedade, 
    vt.p_vazio,
    vt.p_narrativo,
    vt.similaridade_final,
    vt.margem_dominancia
FROM verso v
JOIN livro l ON v.livro_id = l.id
JOIN verso_topico vt ON v.id = vt.verso_id
JOIN verso_sentimento vs ON v.id = vs.verso_id
WHERE vt.status_decisao IN ('Descarte', 'Filtro Brevidade')
  AND vs.label = 'POS'
  AND vt.entropia > 1 -- Alta incerteza (conflito entre eixos)
ORDER BY vt.similaridade_final DESC
LIMIT 20;