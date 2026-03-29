--------------------------------------------------------------------
-- validacoes de criacao e carga do banco de dados, células 1, 2 e 3
--------------------------------------------------------------------
select *
from versao;

select *
from genero_literario;

select *
from testamento;

select gl.nome genero_nome, l.*
from genero_literario gl
join livro l on l.genero_id = gl.id;

select gl.nome genero_nome, l.nome livro_nome, ver.sigla, v.*
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id;

----------------------------------------------------
-- validacoes do processamento, a partir da célula 4
----------------------------------------------------
-- célula 4: carga da tabela verso_limpo
select gl.nome genero_nome, l.nome livro_nome, ver.sigla, 
	v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id
join verso_limpo vl on vl.verso_id = v.id;

-- célula 5: carga das tabelas verso_topico e topico
select gl.nome genero_nome, l.nome livro_nome, ver.sigla, 
	v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo,
	vt.similaridade, t.id, t.antidoto_referencia
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id
join verso_limpo vl on vl.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where t.id <> 3;

-- quantidade de versos por antidoto_referencia e genero_literario
select t.antidoto_referencia, gl.nome genero_nome, count(1) qt_versos
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id
join verso_limpo vl on vl.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where t.id <> 3
group by t.antidoto_referencia, gl.nome
order by t.antidoto_referencia, gl.nome;

select gl.id genero_id, gl.nome genero_nome, l.abreviacao livro_abrev, ver.sigla, 
	v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo,
	vt.similaridade, t.id, t.antidoto_referencia
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id
join verso_limpo vl on vl.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where t.id <> 3 -- desconsidera Outros
and gl.id = 7 -- considera o genero (7 - Apocalíptico)
--and t.antidoto_referencia = 'Esgotamento (Han)' -- considera o antidoto_referencia: Esgotamento (Han), Insignificância (Frankl) ou Transitoriedade (Bauman)
;

-- versos classificados com a maior similaridade (confianca)
SELECT 
    t.antidoto_referencia as Eixo, 
    l.abreviacao || ' ' || v.numero_capitulo || ':' || v.numero_verso as Referencia,
    v.texto, 
    ROUND(vt.similaridade, 4) as Confianca
FROM verso_topico vt
JOIN verso v ON v.id = vt.verso_id
JOIN livro l ON l.id = v.livro_id
JOIN topico t ON t.id = vt.topico_id
WHERE vt.topico_id != 3
GROUP BY vt.topico_id
HAVING Confianca = MAX(round(vt.similaridade, 4))
ORDER BY Confianca DESC;

-- genero literario campeao de cada eixo
SELECT 
    t.antidoto_referencia as Eixo,
    g.nome as Genero_Predominante,
    MAX(contagem) as Volume
FROM (
    SELECT vt.topico_id, l.genero_id, COUNT(*) as contagem
    FROM verso v
	JOIN livro l ON l.id = v.livro_id
    JOIN verso_topico vt ON v.id = vt.verso_id
    GROUP BY topico_id, genero_id
) sub
JOIN topico t ON t.id = sub.topico_id
JOIN genero_literario g ON g.id = sub.genero_id
WHERE t.id != 3
GROUP BY t.id;

-- possiveis incongruencias: eixo x genero
SELECT 
    l.nome as Livro, 
    v.texto, 
    t.antidoto_referencia as Eixo
FROM verso_topico vt
JOIN verso v ON v.id = vt.verso_id
JOIN livro l ON l.id = v.livro_id
JOIN topico t ON t.id = vt.topico_id
WHERE t.id = 1 -- Exemplo: Transitoriedade (Bauman)
AND l.genero_id = 5 -- No gênero Evangelho
ORDER BY vt.similaridade DESC
LIMIT 5;

-- alguns versos classicos
-- Jo 3:16
select l.abreviacao ||' '||v.numero_capitulo||':'||v.numero_verso ref,
	t.antidoto_referencia, vt.similaridade, v.texto, vl.texto_limpo
from livro l
join verso v on v.livro_id = l.id
join verso_limpo vl on vl.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id
where l.abreviacao = 'Jo'
and v.numero_capitulo = 3
and v.numero_verso = 16;

-- Mt 11:28
-- Sl 23:4
-- Ec 1:2
-- Fp 4:13
-- Lm 3:22-23
SELECT 
    l.abreviacao || ' ' || v.numero_capitulo || ':' || v.numero_verso as Ref,
    t.antidoto_referencia as Eixo,
    vt.similaridade as Confianca,
    v.texto
FROM verso v
JOIN verso_topico vt ON v.id = vt.verso_id
JOIN topico t ON t.id = vt.topico_id
JOIN livro l ON l.id = v.livro_id
WHERE (l.abreviacao = 'Jo' AND v.numero_capitulo = 3 AND v.numero_verso = 16)
   OR (l.abreviacao = 'Mt' AND v.numero_capitulo = 11 AND v.numero_verso = 28)
   OR (l.abreviacao = 'Sl' AND v.numero_capitulo = 23 AND v.numero_verso = 4)
   OR (l.abreviacao = 'Ec' AND v.numero_capitulo = 1 AND v.numero_verso = 2)
   OR (l.abreviacao = 'Fp' AND v.numero_capitulo = 4 AND v.numero_verso = 13)
   OR (l.abreviacao = 'Lm' AND v.numero_capitulo = 3 AND v.numero_verso = 22);
   
   
-- célula 6: em qual gênero, a cura é mais forte/presente 
SELECT 
    t.antidoto_referencia as Eixo,
    g.nome as Genero,
    COUNT(*) as Total_Versos,
    -- Percentual de versículos que são efetivamente "Antídotos" (Positivos)
    ROUND(SUM(CASE WHEN vs.sentimento_num = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percentual_Cura,
    -- Percentual de versículos que expõem a "Crise" (Negativos)
    ROUND(SUM(CASE WHEN vs.sentimento_num = -1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percentual_Crise,
    ROUND(AVG(vs.sentimento_num), 3) as Saldo_Emocional
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
JOIN verso_sentimento vs ON vt.verso_id = vs.verso_id
JOIN verso v ON v.id = vt.verso_id
JOIN livro l ON l.id = v.livro_id
JOIN genero_literario g ON g.id = l.genero_id
WHERE t.id != 3
GROUP BY t.antidoto_referencia, g.nome
HAVING Total_Versos > 50 -- Filtro para evitar distorções estatísticas em amostras pequenas
ORDER BY Eixo, Saldo_Emocional DESC;   