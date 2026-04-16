-- inventario
with corpus as (
select 
	gl.id genero_id, gl.nome genero,
	l.nome nome_livro, l.abreviacao abreviacao_livro,
	v.numero_capitulo capitulo, v.numero_verso versiculo, v.texto texto,
	t.antidoto_referencia topico_classificacao_final, 
	vt.similaridade_final topico_score_final, 
	case vs.sentimento_num when 0 then 'Neutro' when 1 then 'Positivo' when -1 then 'Negativo' end sentimento_classificacao_final,
	max(vs.score_pos, vs.score_neg, vs.score_neu) sentimento_score_final,
	-- IA EXPLICAVEL --
	vl.texto_limpo, length(v.texto) tamanho_texto,
	case max(vt.p_exaustao, vt.p_transitoriedade, vt.p_vazio) 
		when vt.p_exaustao then 'Exaustão vs. Refrigério'
		when vt.p_transitoriedade then 'Transitoriedade vs. Solidez'
		when vt.p_vazio then 'Vazio vs. Propósito'
	end topico_melhor_classificacao_existencial,
	max(vt.p_exaustao, vt.p_transitoriedade, vt.p_vazio) topico_melhor_score_existencial,
	vt.p_exaustao topico_score_exaustao, vt.p_transitoriedade topico_score_transitoriedade, vt.p_vazio topico_score_vazio, vt.p_narrativo topico_score_narrativo,
	vs.score_pos sentimento_score_positivo, vs.score_neg sentimento_score_negativo, vs.score_neu sentimento_score_neutro,
	-- calculo da margem de dominancia (melhor score dos eixos existenciais, menos o score do eixo narrativo)
	vt.margem_dominancia,
	-- grau de incerteza da decisao
	-- quanto mais baixo, maior a certeza do enquadramento no eixo escolhido
	-- quanto mais alto, maior a dúvida entre os eixos
	vt.entropia, 
	-- distância entre as duas maiores probabilidades
	vt.gap_confianca,
	-- decisão final
	vt.status_decisao decisao_final
from genero_literario gl
join livro l on l.genero_id = gl.id
join verso v on v.livro_id = l.id
join verso_limpo vl on vl.verso_id = v.id
join verso_sentimento vs on vs.verso_id = v.id
join verso_topico vt on vt.verso_id = v.id
join topico t on t.id = vt.topico_id)
select genero, nome_livro, abreviacao_livro, 
	capitulo, versiculo, texto, 
	abreviacao_livro||' '||capitulo||':'||versiculo||' '||substr(texto, 1, 25)||'...' referencia,
	topico_classificacao_final, topico_score_final,
	sentimento_classificacao_final, sentimento_score_final,
	-- auditoria do texto
	tamanho_texto, texto_limpo,
	-- auditoria da modelagem de tópicos
	topico_melhor_classificacao_existencial,
	topico_melhor_score_existencial,
	topico_score_exaustao, topico_score_transitoriedade, topico_score_vazio, topico_score_narrativo,
	margem_dominancia, entropia, gap_confianca,
	-- auditoria da análise de sentimentos
	sentimento_score_positivo, sentimento_score_negativo, sentimento_score_neutro,
	-- decisao
	decisao_final,
	case 
    when tamanho_texto < 35 and margem_dominancia < 0.25 
        then 'Texto muito curto'
    else 
        case
        when genero_id in (1, 2) and topico_melhor_score_existencial > 0.88 and margem_dominancia > 0.15 
			then 'Classificação existencial ('||round(topico_melhor_score_existencial, 2)||') no eixo '||topico_melhor_classificacao_existencial||' superou o score de referência para o gênero (0.88). A margem de dominância ('||round(margem_dominancia, 2)||') também superou a referência para o eixo (0.15)'
        when genero_id in (3, 4) and topico_melhor_score_existencial > 0.50 
            then 'Classificação existencial ('||round(topico_melhor_score_existencial, 2)||') no eixo '||topico_melhor_classificacao_existencial||' superou o score de referência para o gênero (0.50)'
        when genero_id in (5, 6) and (topico_melhor_score_existencial > 0.60 or (topico_melhor_score_existencial > 0.45 and margem_dominancia > 0.10)) then
            case
                when topico_melhor_score_existencial > 0.60 
                    then 'Classificação existencial ('||round(topico_melhor_score_existencial, 2)||') no eixo '||topico_melhor_classificacao_existencial||' superou o score de referência para o gênero (0.60)'
                else 'Classificação existencial ('||round(topico_melhor_score_existencial, 2)||') no eixo '||topico_melhor_classificacao_existencial||' superou o score de referência para o gênero (0.45). A margem de dominância ('||round(margem_dominancia, 2)||') também superou a referência para o eixo (0.10)'
            end
        when genero_id = 7 and topico_melhor_score_existencial > 0.75
            then 'Classificação existencial ('||round(topico_melhor_score_existencial, 2)||') no eixo '||topico_melhor_classificacao_existencial||' superou o score de referência para o gênero (0.75)'
        else 
            'Regra geral'
        end
    end motivo_decisao
from corpus;