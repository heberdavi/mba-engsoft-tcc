select *
from livro;

select l.abreviacao, v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo
from verso v
	join verso_limpo vl
		on vl.verso_id = v.id
	join livro l
		on l.id = v.livro_id
where l.abreviacao = 'Gn' -- Is, Dn, Rm, Jo, Gn
and v.numero_capitulo = 10 -- 40, 4, 8, 14, 10
and v.numero_verso = 24; -- 29, 3, 28, 27, 24

select l.abreviacao, v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo
from verso_limpo vl
	join verso v
		on v.id = vl.verso_id
	join livro l
		on l.id = v.livro_id
where vl.texto_limpo = 'RUIDO_NOMINAL';
		
select t.antidoto_referencia, l.abreviacao, v.numero_capitulo, v.numero_verso,
	vt.similaridade, v.texto, vl.texto_limpo
from verso v
	join verso_limpo vl
		on vl.verso_id = v.id
	join livro l
		on l.id = v.livro_id
	left join verso_topico vt
		on vt.verso_id = v.id
	left join topico t
		on t.id = vt.topico_id
where l.abreviacao = 'Gn'
and v.numero_capitulo = 10
and v.numero_verso = 24
--and v.numero_verso between 17 and 21
;

SELECT t.antidoto_referencia as Eixo, 
	   COUNT(*) as Total, 
	   AVG(vt.similaridade) as Similaridade_Media
FROM verso_topico vt
JOIN topico t ON vt.topico_id = t.id
GROUP BY t.antidoto_referencia;

select *
from topico t;
/*
0	Esgotamento (Han)
1	Transitoriedade (Bauman)
2	Insignificância (Frankl)
3	Outros
*/

SELECT v.texto, vt.similaridade
FROM verso_topico vt
JOIN verso v ON vt.verso_id = v.id
JOIN livro l ON l.id = v.livro_id
WHERE vt.topico_id = 2
ORDER BY vt.similaridade DESC
LIMIT 5;