------------------------------------------------------------
-- validacoes de criacao e carga do banco de dados, células 1
------------------------------------------------------------
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
-- validacoes do processamento, a partir da célula 3
----------------------------------------------------
-- célula 3: carga da tabela verso_limpo
select gl.nome genero_nome, l.nome livro_nome, ver.sigla, 
	v.numero_capitulo, v.numero_verso, v.texto, vl.texto_limpo
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join versao ver on ver.id = v.versao_id
join verso_limpo vl on vl.verso_id = v.id;

-- célula 4: carga das tabelas verso_topico e topico
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