-- CREATE HELLO SP

--OR REPLACE: opcional
-- se o proc ainda não existir, ele será criado
-- se já existir, será substituído
CREATE OR REPLACE PROCEDURE sp_ola_procedures() LANGUAGE plpgsql
AS $$
BEGIN
RAISE NOTICE 'Olá, procedures'; END;
$$;

CALL sp_ola_procedures()

-- criando
CREATE OR REPLACE PROCEDURE sp_ola_usuario (nome VARCHAR(200)) LANGUAGE plpgsql
AS $$
BEGIN
-- acessando parâmetro pelo nome RAISE NOTICE 'Olá, %', nome;
-- assim também vale
RAISE NOTICE 'Olá, %', $1;
END; $$;
--colocando em execução CALL sp_ola_usuario('Pedro');
CALL sp_ola_usuario(' FATEC IPIRANGA ! ');

--criando
--ambos são IN, pois IN é o padrão
CREATE OR REPLACE PROCEDURE sp_acha_maior (IN valor1 INT, valor2 INT) LANGUAGE plpgsql
AS $$
BEGIN
	IF valor1 > valor2 THEN
		RAISE NOTICE '% é o maior', $1;
ELSE
		RAISE NOTICE '% é o maior', $2;
END IF; 

END;
$$
-- colocando em execução CALL sp_acha_maior (2, 3);
CALL sp_acha_maior(20,100);

-- aqui estamos removendo o proc de nome sp_acha_maior para poder reutilizar o nome
DROP PROCEDURE IF EXISTS sp_acha_maior;
CREATE OR REPLACE PROCEDURE sp_acha_maior (OUT resultado INT, IN valor1 INT, IN valor2 INT) LANGUAGE plpgsql
AS $$
BEGIN
	CASE
	WHEN valor1 > valor2 THEN
		$1 := valor1; 
	ELSE
		resultado := valor2;
	END CASE; 
	END;
$$
--colocando em execução DO $$
DO $$

DECLARE
	resultado INTEGER := 0; 
BEGIN
	CALL sp_acha_maior(resultado, 2, 3);
	RAISE NOTICE '% é o maior', resultado; 
END;
$$


-- 
DROP PROCEDURE IF EXISTS sp_acha_maior;
-- criando
CREATE OR REPLACE PROCEDURE sp_acha_maior (INOUT valor1 INT, IN valor2 INT) LANGUAGE plpgsql
AS $$
BEGIN
IF valor2 > valor1 THEN valor1 := valor2;
END IF; END;
$$
-- colocando em execução DO
DO $$
DECLARE
	valor1 INT := 2; 
	valor2 INT := 3;
BEGIN
	CALL sp_acha_maior(valor1, valor2); RAISE NOTICE '% é o maior', valor1;
	
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'acha maior');
END; 
$$
-- *** 

CREATE OR REPLACE PROCEDURE sp_calcula_media ( VARIADIC valores INT []) LANGUAGE plpgsql
AS $$
DECLARE
	media NUMERIC(10, 2) := 0; valor INT;
BEGIN
	FOREACH valor IN ARRAY valores LOOP
	media := media + valor; END LOOP;
--array_length calcula o número de elementos no array. O segundo parâmetro é o número de dimensões dele
	RAISE NOTICE 'A média é %', media / array_length(valores, 1); 
	
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'calcula media');

	END;
$$
-- 1 parâmetro
CALL sp_calcula_media(1);
-- 2 parâmetros
CALL sp_calcula_media(1, 2);
-- 6 parâmetros
CALL sp_calcula_media(1, 2, 5, 6, 1, 8);

-- não funciona - ERRO
CALL sp_calcula_media (ARRAY[1, 2]);

-- ***
-- CRIAÇÃO DE UM SIS P/ RESTAURANTES
-- ***

-- cria tabela cliente
DROP TABLE IF EXISTS tb_cliente; 
CREATE TABLE tb_cliente (
	cod_cliente SERIAL PRIMARY KEY,
	nome VARCHAR(200) NOT NULL );
SELECT * FROM tb_cliente;
	
-- cria tabela pedido
DROP TABLE IF EXISTS tb_pedido;
CREATE TABLE IF NOT EXISTS tb_pedido(
	cod_pedido SERIAL PRIMARY KEY,
	data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	data_modificacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	status VARCHAR DEFAULT 'aberto',
	cod_cliente INT NOT NULL,
	CONSTRAINT fk_cliente FOREIGN KEY (cod_cliente) REFERENCES
	tb_cliente(cod_cliente) );
SELECT * FROM tb_pedido;

DROP TABLE IF EXISTS tb_tipo_item; 
CREATE TABLE tb_tipo_item(
	cod_tipo SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL );
INSERT INTO tb_tipo_item (descricao) VALUES ('Bebida'), ('Comida'); 
SELECT * FROM tb_tipo_item;

DROP TABLE IF EXISTS tb_item;
CREATE TABLE IF NOT EXISTS tb_item(
	cod_item SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL,
	valor NUMERIC (10, 2) NOT NULL,
	cod_tipo INT NOT NULL,
	CONSTRAINT fk_tipo_item FOREIGN KEY (cod_tipo) REFERENCES
	tb_tipo_item(cod_tipo) );

INSERT INTO tb_item (descricao, valor, cod_tipo) VALUES
	('Refrigerante', 7, 1), 
	('Suco', 8, 1), 
	('Hamburguer', 12, 2), 
	('Batata frita', 9, 2); 
SELECT * FROM tb_item;

DROP TABLE IF EXISTS tb_item_pedido;
CREATE TABLE IF NOT EXISTS tb_item_pedido(
--surrogate key, assim cod_item pode repetir cod_item_pedido SERIAL PRIMARY KEY, cod_item INT,
	cod_pedido INT,
	cod_item INT,
	CONSTRAINT fk_item FOREIGN KEY (cod_item) REFERENCES tb_item (cod_item),
	CONSTRAINT fk_pedido FOREIGN KEY (cod_pedido) REFERENCES tb_pedido (cod_pedido)
);

-- cadastro de cliente
-- se um parâmetro com valor DEFAULT é especificado, aqueles que aparecem depois dele também deve ter valor DEFAULT
CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente (IN nome VARCHAR(200), IN codigo INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
	IF codigo IS NULL THEN
	INSERT INTO tb_cliente (nome) VALUES (nome);
ELSE
	INSERT INTO tb_cliente (codigo, nome) VALUES (codigo, nome);
END IF; 
    INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'cadastrar cliente');
END;
$$
CALL sp_cadastrar_cliente('João da Silva'); 
CALL sp_cadastrar_cliente('Maria Santos'); 
SELECT * FROM tb_cliente;

-- criar um pedido, como se o cliente entrasse no 
-- restaurante e pegasse a comanda 
CREATE OR REPLACE PROCEDURE sp_criar_pedido (OUT cod_pedido INT, cod_cliente INT) LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO tb_pedido (cod_cliente) VALUES (cod_cliente); -- obtém o último valor gerado por SERIAL
	SELECT LASTVAL() INTO cod_pedido;
	
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'cria pedido');
END; 
$$

DO $$ 
DECLARE
--para guardar o código de pedido gerado 
	cod_pedido INT;
-- o código do cliente que vai fazer o pedido 
	cod_cliente INT;
BEGIN
-- pega o código da pessoa cujo nome é "João da Silva"
	SELECT c.cod_cliente FROM tb_cliente c WHERE 
	nome LIKE 'João da Silva' INTO cod_cliente; 
	
	--cria o pedido
	CALL sp_criar_pedido (cod_pedido, cod_cliente);
	RAISE NOTICE 'Código do pedido recém criado: %', cod_pedido;
	

END; 
$$

-- adicionar um item a um pedido
CREATE OR REPLACE PROCEDURE sp_adicionar_item_a_pedido (IN cod_item INT, IN cod_pedido INT)
LANGUAGE plpgsql
AS $$
BEGIN
	--insere novo item
	INSERT INTO tb_item_pedido (cod_item, cod_pedido) VALUES ($1, $2); 
	--atualiza data de modificação do pedido
	UPDATE tb_pedido p SET data_modificacao = CURRENT_TIMESTAMP WHERE p.cod_pedido = $2; 
	
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'adicionou item ao pedido');

END;
$$

CALL sp_adicionar_item_a_pedido (1, 1); 
SELECT * FROM tb_item_pedido; 
SELECT * FROM tb_pedido;

DROP PROCEDURE IF EXISTS sp_calcular_valor_de_um_pedido;
CREATE OR REPLACE PROCEDURE sp_calcular_valor_de_um_pedido (IN p_cod_pedido INT, OUT valor_total INT)
LANGUAGE plpgsql
AS $$
BEGIN
	SELECT SUM(valor) FROM 
		tb_pedido p
	INNER JOIN tb_item_pedido ip ON 
		p.cod_pedido = ip.cod_pedido 
	INNER JOIN tb_item i ON 
		i.cod_item = ip.cod_item
	WHERE p.cod_pedido = $1 INTO $2;
	
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'calcula valor pedido');

END; 
$$
-- ***
DO $$ 
DECLARE
	valor_total INT; 
BEGIN
	CALL sp_calcular_valor_de_um_pedido(1, valor_total); 
	RAISE NOTICE 'Total do pedido %: R$%', 1, valor_total;
END; 
$$

CREATE OR REPLACE PROCEDURE sp_fechar_pedido (IN valor_a_pagar INT, IN cod_pedido INT)
LANGUAGE plpgsql
AS $$
DECLARE
	valor_total INT;
BEGIN
--vamos verificar se o valor_a_pagar é suficiente
	CALL sp_calcular_valor_de_um_pedido (cod_pedido, valor_total); 
	IF valor_a_pagar < valor_total THEN
		RAISE 'R$% insuficiente para pagar a conta de R$%', valor_a_pagar, valor_total;
	UPDATE tb_pedido p SET
	data_modificacao = CURRENT_TIMESTAMP, status = 'fechado'
	WHERE p.cod_pedido = $2;
	-- log
	INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'fechamento pedido');

END IF; 
END;
$$

DO $$ 
BEGIN
	CALL sp_fechar_pedido(200, 1);
END;
$$

SELECT * FROM tb_pedido;

-- ********************** 
-- ATIVIDADE EXERCICIO 11 
-- ********************** 

-- 1.1 Adicione uma tabela de log ao sistema do restaurante. 
-- Ajuste cada procedimento para que ele registre
-- a data em que a operação aconteceu
-- o nome do procedimento executado

DROP TABLE IF EXISTS tb_log;
CREATE TABLE IF NOT EXISTS tb_log(
	cod_log SERIAL PRIMARY KEY,
	data_operacao TIMESTAMP,
	nome_procedimento VARCHAR(500)
);

INSERT INTO tb_log(data_operacao,nome_procedimento) VALUES(CURRENT_TIMESTAMP,'chapa quente');
SELECT * FROM tb_log;















