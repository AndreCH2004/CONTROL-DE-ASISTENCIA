'use strict';

const $ = (id) => document.getElementById(id);

const aviso = new bootstrap.Toast($('aviso'), { delay: 4000 });

/* ---------- Utilidades ---------- */

/** Llama a la API y lanza un Error con el "mensaje" que devuelve el servidor. */
async function api(url, opciones = {}) {
    const respuesta = await fetch(url, {
        headers: { 'Content-Type': 'application/json' },
        ...opciones
    });
    const datos = await respuesta.json().catch(() => ({}));
    if (!respuesta.ok) {
        throw new Error(datos.mensaje || `Error ${respuesta.status}`);
    }
    return datos;
}

function mostrarAviso(texto, tipo = 'success') {
    $('aviso').className = `toast align-items-center border-0 text-bg-${tipo}`;
    $('avisoTexto').textContent = texto;
    aviso.show();
}

/** Escapa texto antes de insertarlo como HTML. */
function esc(valor) {
    const div = document.createElement('div');
    div.textContent = valor ?? '';
    return div.innerHTML;
}

const hoyISO = () => {
    const d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 10);
};

const hora = (h) => (h ? h.slice(0, 5) : '—');

function formatearFecha(iso) {
    const [a, m, d] = iso.split('-');
    return `${d}/${m}/${a}`;
}

function formatearTardanza(min) {
    if (!min) return '0 min';
    const h = Math.floor(min / 60);
    return h ? `${h} h ${min % 60} min` : `${min} min`;
}

/* ---------- Reloj y estado del servidor ---------- */

function actualizarReloj() {
    const ahora = new Date();
    $('reloj').textContent = ahora.toLocaleTimeString('es-PE', { hour12: false });
    $('fechaHoy').textContent = ahora.toLocaleDateString('es-PE', {
        weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
    });
}

async function verificarServidor() {
    const badge = $('estadoServidor');
    try {
        await api('/api/health/db');
        badge.className = 'badge text-bg-success fs-7';
        badge.innerHTML = '<i class="bi bi-circle-fill"></i> En línea';
    } catch {
        badge.className = 'badge text-bg-danger fs-7';
        badge.innerHTML = '<i class="bi bi-exclamation-triangle"></i> Sin conexión';
    }
}

/* ---------- Local de registro (frente de obra de la tablet) ---------- */

const nombreLocal = () => $('frente').selectedOptions[0]?.textContent ?? '—';

async function cargarFrentes() {
    try {
        const frentes = await api('/api/frentes');
        $('frente').innerHTML = frentes.length
            ? frentes.map((f) => `<option value="${f.id}">${esc(f.nombre)} — ${esc(f.distrito)}</option>`).join('')
            : '<option value="">No hay frentes registrados</option>';

        // La tablet recuerda su local de registro.
        const guardado = localStorage.getItem('frenteObra');
        if (guardado && frentes.some((f) => String(f.id) === guardado)) {
            $('frente').value = guardado;
        }
        $('nombreLocalReporte').textContent = nombreLocal();
    } catch (e) {
        mostrarAviso(`No se pudieron cargar los locales: ${e.message}`, 'danger');
    }
}

$('frente').addEventListener('change', () => {
    localStorage.setItem('frenteObra', $('frente').value);
    $('nombreLocalReporte').textContent = nombreLocal();
});

/* ---------- Entrada y cierre del empleado ---------- */

const MARCAJES = {
    entrada: {
        url: '/api/asistencia/entrada',
        resultado: 'resultadoEntrada',
        cuerpo: (codigo) => ({ codigo, idFrenteObra: Number($('frente').value) })
    },
    salida: {
        url: '/api/asistencia/salida',
        resultado: 'resultadoSalida',
        cuerpo: (codigo) => ({ codigo })
    }
};

function pintarResultado(contenedor, r, tipo) {
    const esSalida = tipo === 'salida';
    const tarde = r.minutosTardanza > 0;
    const color = esSalida ? 'primary' : (tarde ? 'warning' : 'success');
    const icono = esSalida ? 'bi-box-arrow-right' : 'bi-box-arrow-in-right';
    const titulo = esSalida ? 'Cierre registrado' : (tarde ? 'Entrada registrada con tardanza' : 'Entrada registrada');

    $(contenedor).innerHTML = `
        <div class="card shadow-sm h-100 resultado border-${color} border-2">
            <div class="card-body p-4">
                <div class="d-flex align-items-center gap-3 mb-4">
                    <i class="bi ${icono} icono text-${color}"></i>
                    <div>
                        <h4 class="mb-0">${titulo}</h4>
                        <div class="text-secondary">${esc(r.nombreEmpleado)} · ${esc(r.codigoEmpleado)}</div>
                    </div>
                </div>
                <div class="row g-3">
                    <div class="col-6 col-md-3"><div class="dato">Entrada</div><div class="valor">${hora(r.horaIngreso)}</div></div>
                    <div class="col-6 col-md-3"><div class="dato">Cierre</div><div class="valor">${hora(r.horaSalida)}</div></div>
                    <div class="col-6 col-md-3"><div class="dato">Horas</div><div class="valor">${Number(r.horasTrabajadas).toFixed(2)}</div></div>
                    <div class="col-6 col-md-3"><div class="dato">Tardanza</div>
                        <div class="valor ${tarde ? 'text-warning-emphasis' : ''}">${formatearTardanza(r.minutosTardanza)}</div></div>
                </div>
                <hr>
                <div class="text-secondary small"><i class="bi bi-geo-alt"></i> ${esc(r.frenteObra)} · ${formatearFecha(r.fecha)}</div>
            </div>
        </div>`;
}

function pintarError(contenedor, mensaje, tipo) {
    $(contenedor).innerHTML = `
        <div class="card shadow-sm h-100 resultado border-danger border-2">
            <div class="card-body p-4 d-flex align-items-center gap-3">
                <i class="bi bi-x-circle icono text-danger"></i>
                <div>
                    <h4 class="mb-1">No se registró ${tipo === 'salida' ? 'el cierre' : 'la entrada'}</h4>
                    <div class="text-secondary">${esc(mensaje)}</div>
                </div>
            </div>
        </div>`;
}

document.querySelectorAll('.form-marcaje').forEach((form) => {
    form.addEventListener('submit', async (ev) => {
        ev.preventDefault();
        const tipo = form.dataset.tipo;
        const config = MARCAJES[tipo];
        const input = form.querySelector('input');
        const boton = form.querySelector('button');

        input.value = input.value.trim().toUpperCase();
        form.classList.add('was-validated');
        if (!form.checkValidity()) return;
        if (tipo === 'entrada' && !$('frente').value) {
            pintarError(config.resultado, 'Seleccione el local de registro arriba a la derecha.', tipo);
            return;
        }

        boton.disabled = true;
        boton.querySelector('.spinner-border').classList.remove('d-none');
        try {
            const registro = await api(config.url, {
                method: 'POST',
                body: JSON.stringify(config.cuerpo(input.value))
            });
            pintarResultado(config.resultado, registro, tipo);
            input.value = '';
            form.classList.remove('was-validated');
        } catch (e) {
            pintarError(config.resultado, e.message, tipo);
        } finally {
            boton.disabled = false;
            boton.querySelector('.spinner-border').classList.add('d-none');
            input.focus();
        }
    });
});

// Al cambiar de pestaña, el cursor queda listo en el campo de código.
document.querySelectorAll('[data-bs-toggle="pill"]').forEach((boton) => {
    boton.addEventListener('shown.bs.tab', () => {
        document.querySelector(`${boton.dataset.bsTarget} input`)?.focus();
    });
});

/* ---------- Reporte ---------- */

function tarjetaResumen(titulo, valor, icono, color) {
    return `
        <div class="col-6 col-md-3">
            <div class="border rounded-3 p-3 bg-body">
                <div class="dato"><i class="bi ${icono} text-${color}"></i> ${titulo}</div>
                <div class="valor">${valor}</div>
            </div>
        </div>`;
}

function estado(r) {
    if (r.esFalta) return '<span class="badge text-bg-danger">Falta</span>';
    if (r.horaSalida) return '<span class="badge text-bg-success">Completo</span>';
    return '<span class="badge text-bg-secondary">Sin cierre</span>';
}

$('formReporte').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const params = new URLSearchParams({
        idFrente: $('frente').value,
        inicio: $('inicio').value,
        fin: $('fin').value
    });
    const tbody = $('tablaReporte');
    tbody.innerHTML = '<tr><td colspan="8" class="text-center py-4"><div class="spinner-border spinner-border-sm"></div></td></tr>';

    try {
        const filas = await api(`/api/asistencia/reporte?${params}`);
        const horas = filas.reduce((s, r) => s + Number(r.horasTrabajadas), 0);

        $('resumenReporte').innerHTML =
            tarjetaResumen('Registros', filas.length, 'bi-list-check', 'primary') +
            tarjetaResumen('Horas trabajadas', horas.toFixed(2), 'bi-clock', 'success') +
            tarjetaResumen('Tardanzas', filas.filter((r) => r.minutosTardanza > 0).length, 'bi-alarm', 'warning') +
            tarjetaResumen('Faltas', filas.filter((r) => r.esFalta).length, 'bi-person-x', 'danger');

        tbody.innerHTML = filas.length
            ? filas.map((r) => `
                <tr>
                    <td>${formatearFecha(r.fecha)}</td>
                    <td><code>${esc(r.codigoEmpleado)}</code></td>
                    <td>${esc(r.nombreEmpleado)}</td>
                    <td>${hora(r.horaIngreso)}</td>
                    <td>${hora(r.horaSalida)}</td>
                    <td class="text-end">${Number(r.horasTrabajadas).toFixed(2)}</td>
                    <td class="text-end">${r.minutosTardanza ? formatearTardanza(r.minutosTardanza) : '—'}</td>
                    <td>${estado(r)}</td>
                </tr>`).join('')
            : '<tr><td colspan="8" class="text-center text-secondary py-4">No hay registros en el periodo.</td></tr>';
    } catch (e) {
        $('resumenReporte').innerHTML = '';
        tbody.innerHTML = `<tr><td colspan="8" class="text-center text-danger py-4">${esc(e.message)}</td></tr>`;
    }
});

/* ---------- Inicio ---------- */

(function iniciar() {
    const hoy = hoyISO();
    $('inicio').value = hoy.slice(0, 8) + '01';
    $('fin').value = hoy;

    actualizarReloj();
    setInterval(actualizarReloj, 1000);
    verificarServidor();
    setInterval(verificarServidor, 30000);
    cargarFrentes();
})();
