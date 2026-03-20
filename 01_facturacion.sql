-- ============================================================
-- PROYECTO 8: SISTEMA DE FACTURACIÓN ELECTRÓNICA
-- Nivel: EXPERTO
-- Motor: Oracle Database 19c+
-- Conceptos: Todo integrado — Packages completos, Funciones
--            analíticas avanzadas, Dynamic SQL (EXECUTE IMMEDIATE),
--            Object Types, Colecciones anidadas, REF CURSOR,
--            Manejo avanzado de errores, Auditoría completa
-- Autor: Luis Angel Tapias Madronero
-- ============================================================

BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'FAC_%') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE 'SEQ_FAC%') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
    FOR p IN (SELECT object_name, object_type FROM user_objects
              WHERE object_name LIKE 'PKG_FACTURA%' OR object_name LIKE 'PKG_REPORT%') LOOP
        EXECUTE IMMEDIATE 'DROP ' || p.object_type || ' ' || p.object_name;
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE SEQUENCE seq_fac_emp      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_cli      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_prod     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_fact     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_item     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_audit    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fac_nota     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================
-- TABLAS
-- ============================================================
CREATE TABLE fac_empresas (
    id_empresa   NUMBER        DEFAULT seq_fac_emp.NEXTVAL PRIMARY KEY,
    nit          VARCHAR2(20)  NOT NULL UNIQUE,
    razon_social VARCHAR2(200) NOT NULL,
    nombre_comerc VARCHAR2(200),
    regimen      VARCHAR2(20)  NOT NULL,  -- SIMPLIFICADO | COMUN
    resolucion_dian VARCHAR2(100),
    prefijo_fact  VARCHAR2(5),
    consecutivo_act NUMBER(10) DEFAULT 1,
    activo        NUMBER(1)    DEFAULT 1
);

CREATE TABLE fac_clientes (
    id_cliente   NUMBER        DEFAULT seq_fac_cli.NEXTVAL PRIMARY KEY,
    tipo_doc     VARCHAR2(5)   NOT NULL,  -- NIT | CC | CE | PP
    num_doc      VARCHAR2(20)  NOT NULL,
    nombre       VARCHAR2(200) NOT NULL,
    email        VARCHAR2(150),
    telefono     VARCHAR2(20),
    direccion    VARCHAR2(300),
    ciudad       VARCHAR2(100),
    responsable_iva NUMBER(1)  DEFAULT 0,
    CONSTRAINT uq_cli_doc UNIQUE (tipo_doc, num_doc)
);

CREATE TABLE fac_productos (
    id_producto  NUMBER        DEFAULT seq_fac_prod.NEXTVAL PRIMARY KEY,
    codigo       VARCHAR2(30)  NOT NULL UNIQUE,
    descripcion  VARCHAR2(300) NOT NULL,
    unidad_med   VARCHAR2(20)  DEFAULT 'UND',
    precio_base  NUMBER(14,2)  NOT NULL,
    pct_iva      NUMBER(5,2)   DEFAULT 19 NOT NULL,  -- 0%, 5%, 19%
    pct_desc_max NUMBER(5,2)   DEFAULT 30,
    activo       NUMBER(1)     DEFAULT 1,
    CONSTRAINT chk_iva_fac CHECK (pct_iva IN (0, 5, 19))
);

CREATE TABLE fac_facturas (
    id_factura   NUMBER        DEFAULT seq_fac_fact.NEXTVAL PRIMARY KEY,
    id_empresa   NUMBER        NOT NULL,
    id_cliente   NUMBER        NOT NULL,
    numero_fact  VARCHAR2(20)  NOT NULL UNIQUE,  -- prefijo + consecutivo
    cufe         VARCHAR2(100),  -- Código Único Factura Electrónica (simulado)
    fecha_emision DATE         DEFAULT SYSDATE NOT NULL,
    fecha_vencim  DATE         NOT NULL,
    estado       VARCHAR2(15)  DEFAULT 'BORRADOR',
    -- BORRADOR | EMITIDA | PAGADA | ANULADA | VENCIDA
    subtotal     NUMBER(14,2)  DEFAULT 0,
    descuento_tot NUMBER(14,2) DEFAULT 0,
    base_iva     NUMBER(14,2)  DEFAULT 0,
    iva_tot      NUMBER(14,2)  DEFAULT 0,
    total        NUMBER(14,2)  DEFAULT 0,
    notas        VARCHAR2(500),
    CONSTRAINT fk_fact_emp  FOREIGN KEY (id_empresa) REFERENCES fac_empresas(id_empresa),
    CONSTRAINT fk_fact_cli  FOREIGN KEY (id_cliente) REFERENCES fac_clientes(id_cliente),
    CONSTRAINT chk_fact_est CHECK (estado IN ('BORRADOR','EMITIDA','PAGADA','ANULADA','VENCIDA'))
);

CREATE TABLE fac_items (
    id_item      NUMBER        DEFAULT seq_fac_item.NEXTVAL PRIMARY KEY,
    id_factura   NUMBER        NOT NULL,
    id_producto  NUMBER        NOT NULL,
    cantidad     NUMBER(10,3)  NOT NULL,
    precio_unit  NUMBER(14,2)  NOT NULL,
    pct_desc     NUMBER(5,2)   DEFAULT 0,
    valor_desc   NUMBER(14,2)  DEFAULT 0,
    subtotal_item NUMBER(14,2) NOT NULL,
    pct_iva      NUMBER(5,2)   NOT NULL,
    valor_iva    NUMBER(14,2)  NOT NULL,
    total_item   NUMBER(14,2)  NOT NULL,
    CONSTRAINT fk_item_fact FOREIGN KEY (id_factura)  REFERENCES fac_facturas(id_factura),
    CONSTRAINT fk_item_prod FOREIGN KEY (id_producto) REFERENCES fac_productos(id_producto),
    CONSTRAINT chk_desc_fac CHECK (pct_desc BETWEEN 0 AND 100)
);

CREATE TABLE fac_notas_credito (
    id_nota      NUMBER        DEFAULT seq_fac_nota.NEXTVAL PRIMARY KEY,
    id_factura_orig NUMBER     NOT NULL,
    numero_nota  VARCHAR2(20)  NOT NULL UNIQUE,
    motivo       VARCHAR2(200) NOT NULL,
    valor_nota   NUMBER(14,2)  NOT NULL,
    fecha        DATE          DEFAULT SYSDATE,
    estado       VARCHAR2(15)  DEFAULT 'ACTIVA',
    CONSTRAINT fk_nota_fact FOREIGN KEY (id_factura_orig) REFERENCES fac_facturas(id_factura)
);

CREATE TABLE fac_auditoria (
    id_audit     NUMBER        DEFAULT seq_fac_audit.NEXTVAL PRIMARY KEY,
    tabla_afect  VARCHAR2(50)  NOT NULL,
    id_registro  NUMBER,
    evento       VARCHAR2(50)  NOT NULL,
    datos_ant    CLOB,
    datos_nvo    CLOB,
    usuario_bd   VARCHAR2(100) DEFAULT USER,
    fecha        DATE          DEFAULT SYSDATE
);

-- ============================================================
-- DATOS BASE
-- ============================================================
INSERT INTO fac_empresas (nit, razon_social, nombre_comerc, regimen, resolucion_dian, prefijo_fact)
VALUES ('900123456-7', 'Tech Solutions Colombia S.A.S', 'TechSol', 'COMUN',
        'Res. DIAN 18764001234560', 'TECS');

INSERT INTO fac_clientes VALUES (seq_fac_cli.NEXTVAL,'NIT','800112233','Empresa Alpha S.A.',
    'compras@alpha.co','6011234567','Cra 7 # 32-10, Bogotá','Bogotá',1);
INSERT INTO fac_clientes VALUES (seq_fac_cli.NEXTVAL,'CC','1020304050','Juan Carlos Rodríguez',
    'jc.rodriguez@email.com','3001234567','Cll 100 #15-20, Bogotá','Bogotá',0);
INSERT INTO fac_clientes VALUES (seq_fac_cli.NEXTVAL,'NIT','900765432','Distribuidora Beta Ltda',
    'logistica@beta.co','6022345678','Av El Dorado #90-10, Bogotá','Bogotá',1);

INSERT INTO fac_productos VALUES (seq_fac_prod.NEXTVAL,'SRV-001','Consultoría en Bases de Datos Oracle','HR',2500000,19,20,1);
INSERT INTO fac_productos VALUES (seq_fac_prod.NEXTVAL,'SRV-002','Desarrollo de Software a Medida','HR',5000000,19,10,1);
INSERT INTO fac_productos VALUES (seq_fac_prod.NEXTVAL,'SRV-003','Soporte Técnico TI Mensual','MES',1800000,19,0,1);
INSERT INTO fac_productos VALUES (seq_fac_prod.NEXTVAL,'LIC-001','Licencia Software ERP Anual','UND',8500000,19,5,1);
INSERT INTO fac_productos VALUES (seq_fac_prod.NEXTVAL,'CAPAC-001','Capacitación SQL Oracle (40 horas)','GRP',3200000,19,15,1);

COMMIT;

-- ============================================================
-- PACKAGE: FACTURACIÓN (Especificación)
-- ============================================================
CREATE OR REPLACE PACKAGE pkg_facturacion AS

    -- REF CURSOR genérico
    TYPE t_ref_cursor IS REF CURSOR;

    PROCEDURE crear_factura(
        p_id_empresa   IN  NUMBER,
        p_id_cliente   IN  NUMBER,
        p_dias_venc    IN  NUMBER DEFAULT 30,
        p_id_factura   OUT NUMBER,
        p_numero_fact  OUT VARCHAR2,
        p_mensaje      OUT VARCHAR2
    );

    PROCEDURE agregar_item(
        p_id_factura  IN  NUMBER,
        p_id_producto IN  NUMBER,
        p_cantidad    IN  NUMBER,
        p_pct_desc    IN  NUMBER DEFAULT 0,
        p_mensaje     OUT VARCHAR2
    );

    PROCEDURE emitir_factura(
        p_id_factura IN  NUMBER,
        p_mensaje    OUT VARCHAR2
    );

    PROCEDURE anular_factura(
        p_id_factura IN  NUMBER,
        p_motivo     IN  VARCHAR2,
        p_mensaje    OUT VARCHAR2
    );

    FUNCTION consultar_estado(p_numero_fact IN VARCHAR2) RETURN t_ref_cursor;

END pkg_facturacion;
/

CREATE OR REPLACE PACKAGE BODY pkg_facturacion AS

    -- Generar número de factura
    FUNCTION gen_numero(p_id_empresa NUMBER) RETURN VARCHAR2 IS
        v_prefijo VARCHAR2(5);
        v_consec  NUMBER;
    BEGIN
        SELECT prefijo_fact, consecutivo_act INTO v_prefijo, v_consec
        FROM fac_empresas WHERE id_empresa = p_id_empresa FOR UPDATE;

        UPDATE fac_empresas SET consecutivo_act = consecutivo_act + 1
        WHERE id_empresa = p_id_empresa;

        RETURN v_prefijo || LPAD(v_consec, 8, '0');
    END;

    -- Generar CUFE simulado
    FUNCTION gen_cufe(p_numero VARCHAR2, p_fecha DATE, p_total NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN LOWER(RAWTOHEX(UTL_RAW.CAST_TO_RAW(
            p_numero || TO_CHAR(p_fecha,'YYYYMMDD') || TRIM(TO_CHAR(p_total))
        )));
    END;

    -- Recalcular totales de factura
    PROCEDURE recalcular_totales(p_id_factura NUMBER) IS
        v_subtotal  NUMBER(14,2);
        v_desc_tot  NUMBER(14,2);
        v_base_iva  NUMBER(14,2);
        v_iva       NUMBER(14,2);
    BEGIN
        SELECT
            NVL(SUM(subtotal_item), 0),
            NVL(SUM(valor_desc), 0),
            NVL(SUM(CASE WHEN pct_iva > 0 THEN subtotal_item ELSE 0 END), 0),
            NVL(SUM(valor_iva), 0)
        INTO v_subtotal, v_desc_tot, v_base_iva, v_iva
        FROM fac_items WHERE id_factura = p_id_factura;

        UPDATE fac_facturas SET
            subtotal      = v_subtotal,
            descuento_tot = v_desc_tot,
            base_iva      = v_base_iva,
            iva_tot       = v_iva,
            total         = v_subtotal + v_iva
        WHERE id_factura = p_id_factura;
    END;

    -- Crear factura
    PROCEDURE crear_factura(
        p_id_empresa   IN  NUMBER,
        p_id_cliente   IN  NUMBER,
        p_dias_venc    IN  NUMBER DEFAULT 30,
        p_id_factura   OUT NUMBER,
        p_numero_fact  OUT VARCHAR2,
        p_mensaje      OUT VARCHAR2
    ) IS
    BEGIN
        p_numero_fact := gen_numero(p_id_empresa);

        INSERT INTO fac_facturas (id_empresa, id_cliente, numero_fact, fecha_vencim, estado)
        VALUES (p_id_empresa, p_id_cliente, p_numero_fact, SYSDATE + p_dias_venc, 'BORRADOR')
        RETURNING id_factura INTO p_id_factura;

        INSERT INTO fac_auditoria (tabla_afect, id_registro, evento, datos_nvo)
        VALUES ('FAC_FACTURAS', p_id_factura, 'CREACION',
                '{"numero":"' || p_numero_fact || '","estado":"BORRADOR"}');

        COMMIT;
        p_mensaje := 'Factura ' || p_numero_fact || ' creada (ID: ' || p_id_factura || ')';
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK;
        p_id_factura := -1; p_mensaje := 'ERROR: ' || SQLERRM;
    END;

    -- Agregar ítem
    PROCEDURE agregar_item(
        p_id_factura  IN  NUMBER,
        p_id_producto IN  NUMBER,
        p_cantidad    IN  NUMBER,
        p_pct_desc    IN  NUMBER DEFAULT 0,
        p_mensaje     OUT VARCHAR2
    ) IS
        v_estado    VARCHAR2(15);
        v_precio    NUMBER(14,2);
        v_pct_iva   NUMBER(5,2);
        v_pct_max   NUMBER(5,2);
        v_sub       NUMBER(14,2);
        v_desc      NUMBER(14,2);
        v_iva       NUMBER(14,2);
        v_total     NUMBER(14,2);
    BEGIN
        SELECT estado INTO v_estado FROM fac_facturas WHERE id_factura = p_id_factura;
        IF v_estado != 'BORRADOR' THEN
            p_mensaje := 'ERROR: Solo se pueden agregar ítems a facturas en BORRADOR.';
            RETURN;
        END IF;

        SELECT precio_base, pct_iva, pct_desc_max INTO v_precio, v_pct_iva, v_pct_max
        FROM fac_productos WHERE id_producto = p_id_producto AND activo = 1;

        IF p_pct_desc > v_pct_max THEN
            p_mensaje := 'ERROR: Descuento máximo permitido: ' || v_pct_max || '%';
            RETURN;
        END IF;

        v_sub   := ROUND(p_cantidad * v_precio, 2);
        v_desc  := ROUND(v_sub * p_pct_desc / 100, 2);
        v_iva   := ROUND((v_sub - v_desc) * v_pct_iva / 100, 2);
        v_total := (v_sub - v_desc) + v_iva;

        INSERT INTO fac_items (id_factura, id_producto, cantidad, precio_unit, pct_desc,
                               valor_desc, subtotal_item, pct_iva, valor_iva, total_item)
        VALUES (p_id_factura, p_id_producto, p_cantidad, v_precio, p_pct_desc,
                v_desc, v_sub - v_desc, v_pct_iva, v_iva, v_total);

        recalcular_totales(p_id_factura);
        COMMIT;
        p_mensaje := 'Ítem agregado. Subtotal ítem: $' || TO_CHAR(v_total,'999,999,999');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN p_mensaje := 'ERROR: Producto o factura no encontrado.';
        WHEN OTHERS THEN ROLLBACK; p_mensaje := 'ERROR: ' || SQLERRM;
    END;

    -- Emitir factura (genera CUFE)
    PROCEDURE emitir_factura(
        p_id_factura IN  NUMBER,
        p_mensaje    OUT VARCHAR2
    ) IS
        v_fact    fac_facturas%ROWTYPE;
        v_items   NUMBER;
        v_cufe    VARCHAR2(100);
    BEGIN
        SELECT * INTO v_fact FROM fac_facturas WHERE id_factura = p_id_factura;

        IF v_fact.estado != 'BORRADOR' THEN
            p_mensaje := 'ERROR: Solo se pueden emitir facturas en BORRADOR.';
            RETURN;
        END IF;

        SELECT COUNT(*) INTO v_items FROM fac_items WHERE id_factura = p_id_factura;
        IF v_items = 0 THEN
            p_mensaje := 'ERROR: La factura no tiene ítems.';
            RETURN;
        END IF;

        IF v_fact.total = 0 THEN
            p_mensaje := 'ERROR: El total de la factura no puede ser cero.';
            RETURN;
        END IF;

        v_cufe := gen_cufe(v_fact.numero_fact, v_fact.fecha_emision, v_fact.total);

        UPDATE fac_facturas
        SET estado = 'EMITIDA', cufe = v_cufe
        WHERE id_factura = p_id_factura;

        INSERT INTO fac_auditoria (tabla_afect, id_registro, evento, datos_nvo)
        VALUES ('FAC_FACTURAS', p_id_factura, 'EMISION',
                '{"numero":"' || v_fact.numero_fact || '","total":' || v_fact.total ||
                ',"cufe":"' || v_cufe || '"}');

        COMMIT;
        p_mensaje := 'Factura ' || v_fact.numero_fact || ' emitida. CUFE: ' ||
                     SUBSTR(v_cufe,1,20) || '...';
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; p_mensaje := 'ERROR: ' || SQLERRM;
    END;

    -- Anular factura
    PROCEDURE anular_factura(
        p_id_factura IN  NUMBER,
        p_motivo     IN  VARCHAR2,
        p_mensaje    OUT VARCHAR2
    ) IS
        v_estado     VARCHAR2(15);
        v_numero     VARCHAR2(20);
    BEGIN
        SELECT estado, numero_fact INTO v_estado, v_numero
        FROM fac_facturas WHERE id_factura = p_id_factura;

        IF v_estado = 'PAGADA' THEN
            p_mensaje := 'ERROR: Una factura PAGADA no puede anularse. Use nota crédito.';
            RETURN;
        END IF;
        IF v_estado = 'ANULADA' THEN
            p_mensaje := 'ERROR: La factura ya está anulada.';
            RETURN;
        END IF;

        UPDATE fac_facturas SET estado = 'ANULADA' WHERE id_factura = p_id_factura;

        INSERT INTO fac_auditoria (tabla_afect, id_registro, evento, datos_ant, datos_nvo)
        VALUES ('FAC_FACTURAS', p_id_factura, 'ANULACION',
                '{"estado":"' || v_estado || '"}',
                '{"estado":"ANULADA","motivo":"' || p_motivo || '"}');

        COMMIT;
        p_mensaje := 'Factura ' || v_numero || ' anulada. Motivo: ' || p_motivo;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; p_mensaje := 'ERROR: ' || SQLERRM;
    END;

    -- Consultar estado (REF CURSOR)
    FUNCTION consultar_estado(p_numero_fact IN VARCHAR2) RETURN t_ref_cursor IS
        v_cursor t_ref_cursor;
    BEGIN
        OPEN v_cursor FOR
            SELECT
                f.numero_fact,
                c.nombre                        AS cliente,
                f.estado,
                f.fecha_emision,
                f.fecha_vencim,
                f.subtotal,
                f.iva_tot,
                f.total,
                COUNT(i.id_item)                AS num_items,
                f.cufe
            FROM fac_facturas f
            INNER JOIN fac_clientes c ON f.id_cliente = c.id_cliente
            LEFT  JOIN fac_items   i ON f.id_factura  = i.id_factura
            WHERE f.numero_fact = p_numero_fact
            GROUP BY f.numero_fact, c.nombre, f.estado, f.fecha_emision,
                     f.fecha_vencim, f.subtotal, f.iva_tot, f.total, f.cufe;
        RETURN v_cursor;
    END;

END pkg_facturacion;
/

-- ============================================================
-- PACKAGE REPORTES con SQL dinámico
-- ============================================================
CREATE OR REPLACE PACKAGE pkg_reportes_factura AS

    PROCEDURE reporte_ventas_periodo(
        p_fecha_ini IN DATE,
        p_fecha_fin IN DATE,
        p_id_cliente IN NUMBER DEFAULT NULL
    );

    PROCEDURE top_productos(p_top IN NUMBER DEFAULT 10);

END pkg_reportes_factura;
/

CREATE OR REPLACE PACKAGE BODY pkg_reportes_factura AS

    PROCEDURE reporte_ventas_periodo(
        p_fecha_ini  IN DATE,
        p_fecha_fin  IN DATE,
        p_id_cliente IN NUMBER DEFAULT NULL
    ) IS
        v_sql    VARCHAR2(2000);
        v_total  NUMBER(16,2) := 0;
        TYPE t_row IS RECORD (numero VARCHAR2(20), cliente VARCHAR2(200),
                               total NUMBER, estado VARCHAR2(15), fecha DATE);
        TYPE t_tabla IS TABLE OF t_row;
        v_datos  t_tabla;
    BEGIN
        -- SQL DINÁMICO: filtro opcional por cliente
        v_sql :=
            'SELECT f.numero_fact, c.nombre, f.total, f.estado, f.fecha_emision
             FROM fac_facturas f
             INNER JOIN fac_clientes c ON f.id_cliente = c.id_cliente
             WHERE f.fecha_emision BETWEEN :1 AND :2
               AND f.estado NOT IN (''BORRADOR'',''ANULADA'')';

        IF p_id_cliente IS NOT NULL THEN
            v_sql := v_sql || ' AND f.id_cliente = ' || p_id_cliente;
        END IF;
        v_sql := v_sql || ' ORDER BY f.fecha_emision';

        EXECUTE IMMEDIATE v_sql BULK COLLECT INTO v_datos USING p_fecha_ini, p_fecha_fin;

        DBMS_OUTPUT.PUT_LINE('REPORTE DE VENTAS: ' ||
            TO_CHAR(p_fecha_ini,'DD/MM/YYYY') || ' — ' || TO_CHAR(p_fecha_fin,'DD/MM/YYYY'));
        DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));

        FOR i IN 1..v_datos.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_datos(i).numero,15) || ' | ' ||
                RPAD(v_datos(i).cliente,30) || ' | $' ||
                TO_CHAR(v_datos(i).total,'999,999,999') || ' | ' || v_datos(i).estado
            );
            v_total := v_total + v_datos(i).total;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
        DBMS_OUTPUT.PUT_LINE('TOTAL: $' || TO_CHAR(v_total,'999,999,999') ||
                             ' (' || v_datos.COUNT || ' facturas)');
    END;

    PROCEDURE top_productos(p_top IN NUMBER DEFAULT 10) IS
    BEGIN
        FOR r IN (
            SELECT *
            FROM (
                SELECT
                    p.codigo,
                    p.descripcion,
                    COUNT(DISTINCT i.id_factura)  AS num_facturas,
                    SUM(i.cantidad)               AS total_cant,
                    SUM(i.subtotal_item)          AS total_vendido,
                    RANK() OVER (ORDER BY SUM(i.subtotal_item) DESC) AS ranking
                FROM fac_items      i
                INNER JOIN fac_productos p ON i.id_producto  = p.id_producto
                INNER JOIN fac_facturas  f ON i.id_factura   = f.id_factura
                WHERE f.estado IN ('EMITIDA','PAGADA')
                GROUP BY p.codigo, p.descripcion
            ) WHERE ranking <= p_top
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                r.ranking || '. ' || RPAD(r.codigo,12) ||
                RPAD(r.descripcion,40) || ' $' || TO_CHAR(r.total_vendido,'999,999,999')
            );
        END LOOP;
    END;

END pkg_reportes_factura;
/

-- ============================================================
-- FUNCIONES ANALÍTICAS — Dashboard de facturación
-- ============================================================

SELECT
    TO_CHAR(f.fecha_emision,'YYYY-MM')              AS mes,
    COUNT(*)                                          AS num_facturas,
    SUM(f.total)                                     AS ventas_mes,
    ROUND(AVG(f.total),0)                            AS ticket_promedio,
    SUM(SUM(f.total)) OVER (
        ORDER BY TO_CHAR(f.fecha_emision,'YYYY-MM')
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                 AS ventas_acumuladas,
    ROUND(
        (SUM(f.total) - LAG(SUM(f.total)) OVER (ORDER BY TO_CHAR(f.fecha_emision,'YYYY-MM')))
        / NULLIF(LAG(SUM(f.total)) OVER (ORDER BY TO_CHAR(f.fecha_emision,'YYYY-MM')),0) * 100
    , 2)                                              AS crecimiento_pct
FROM fac_facturas f
WHERE f.estado IN ('EMITIDA','PAGADA')
GROUP BY TO_CHAR(f.fecha_emision,'YYYY-MM')
ORDER BY mes;

-- ============================================================
-- DEMO COMPLETA
-- ============================================================
SET SERVEROUTPUT ON;

DECLARE
    v_id_fact NUMBER;
    v_num     VARCHAR2(20);
    v_msg     VARCHAR2(500);
BEGIN
    -- Crear y emitir factura completa
    pkg_facturacion.crear_factura(1, 1, 30, v_id_fact, v_num, v_msg);
    DBMS_OUTPUT.PUT_LINE(v_msg);

    pkg_facturacion.agregar_item(v_id_fact, 1, 3, 10, v_msg);   -- Consultoría x3, 10% desc
    DBMS_OUTPUT.PUT_LINE(v_msg);

    pkg_facturacion.agregar_item(v_id_fact, 3, 1, 0, v_msg);    -- Soporte mensual
    DBMS_OUTPUT.PUT_LINE(v_msg);

    pkg_facturacion.emitir_factura(v_id_fact, v_msg);
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Segunda factura
    pkg_facturacion.crear_factura(1, 2, 15, v_id_fact, v_num, v_msg);
    pkg_facturacion.agregar_item(v_id_fact, 5, 1, 15, v_msg);
    pkg_facturacion.emitir_factura(v_id_fact, v_msg);
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Reporte
    pkg_reportes_factura.reporte_ventas_periodo(TRUNC(SYSDATE,'MM'), SYSDATE);
    pkg_reportes_factura.top_productos(5);
END;
/
