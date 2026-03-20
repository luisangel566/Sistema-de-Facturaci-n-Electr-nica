# Sistema-de-Facturaci-n-Electr-nica
Sistema de Facturación Electrónica en Oracle 19c que permite gestionar empresas, clientes y productos, crear y emitir facturas, manejar notas de crédito y generar reportes y dashboards de ventas.
Proyecto 8: Sistema de Facturación Electrónica

Autor: Luis Angel Tapias Madronero
Nivel: Experto
Motor: Oracle Database 19c+
Tecnologías y Conceptos: Packages PL/SQL, Funciones Analíticas, Dynamic SQL, Object Types, Colecciones Anidadas, REF CURSOR, Auditoría, Manejo avanzado de errores.

1. Descripción

Este proyecto implementa un sistema completo de facturación electrónica para empresas, integrando:

Gestión de empresas y clientes.

Catálogo de productos y servicios.

Creación, edición y emisión de facturas electrónicas, incluyendo CUFE simulado.

Soporte de notas de crédito y anulación de facturas.

Auditoría completa de cambios.

Reportes dinámicos y análisis de ventas con funciones analíticas.

El sistema está diseñado con buenas prácticas de PL/SQL, incluyendo paquetes modulares, control de errores y uso de secuencias para identificación única.

2. Estructura de la Base de Datos
Secuencias
Secuencia	Uso
seq_fac_emp	Empresas
seq_fac_cli	Clientes
seq_fac_prod	Productos
seq_fac_fact	Facturas
seq_fac_item	Ítems de factura
seq_fac_audit	Auditoría
seq_fac_nota	Notas de crédito
Tablas Principales

fac_empresas: Datos de empresas emisoras.

fac_clientes: Clientes con tipo de documento y contacto.

fac_productos: Productos o servicios con precio, IVA y descuentos máximos.

fac_facturas: Facturas, estado, totales y CUFE.

fac_items: Detalle de cada factura, cálculo de subtotal, IVA y descuentos.

fac_notas_credito: Notas de crédito asociadas a facturas.

fac_auditoria: Registro de todos los cambios importantes.

3. Paquetes PL/SQL
3.1 pkg_facturacion

Funcionalidad: Gestión de facturación.

crear_factura: Genera una factura en estado BORRADOR.

agregar_item: Agrega productos/servicios a la factura.

emitir_factura: Cambia el estado a EMITIDA y genera CUFE.

anular_factura: Anula una factura y registra auditoría.

consultar_estado: Devuelve un REF CURSOR con el estado y detalle de la factura.

Funciones internas:

gen_numero: Genera número de factura con prefijo y consecutivo.

gen_cufe: Genera un CUFE simulado.

recalcular_totales: Calcula subtotal, descuento, IVA y total de la factura.

3.2 pkg_reportes_factura

Funcionalidad: Reportes y análisis de ventas.

reporte_ventas_periodo(p_fecha_ini, p_fecha_fin, p_id_cliente): Muestra ventas por periodo, opcionalmente filtrando por cliente.

top_productos(p_top): Muestra los productos más vendidos según el valor total.

Conceptos utilizados:

SQL dinámico (EXECUTE IMMEDIATE)

BULK COLLECT

Funciones analíticas (RANK, SUM() OVER)

4. Dashboard de Facturación

Consulta analítica de ventas por mes, incluye:

Número de facturas.

Ventas totales.

Ticket promedio.

Ventas acumuladas.

Crecimiento porcentual mensual.
