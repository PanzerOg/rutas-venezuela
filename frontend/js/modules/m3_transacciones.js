// Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
const byId = (id) => document.getElementById(id);
const api = '/api/m3';
const sessionKey = 'rutas-m3-session';
let token = sessionStorage.getItem(sessionKey);
let profile;
let catalogs;
let section;
let page = 1;
let sort = '';
let direction = 'asc';
let requestNumber = 0;
let editorAction;
let pendingIncidents = 0;
let fieldNumber = 0;

const actorLabels = { Visitante: 'Visitante', Guia: 'Guía turístico', Comercio: 'Comercio aliado', Ente: 'Ente público', Admin: 'Administración' };
const severities = [['Bajo', 'Bajo'], ['Medio', 'Medio'], ['Critico', 'Crítico']];
const incidentStates = ['Preliminar', 'Activo', 'Fuera de plazo', 'Resuelto'];
const passStates = ['Emitido', 'Canjeado', 'Cancelado', 'Vencido'];
const weekdays = [['Lunes', 'Lunes'], ['Martes', 'Martes'], ['Miercoles', 'Miércoles'], ['Jueves', 'Jueves'], ['Viernes', 'Viernes'], ['Sabado', 'Sábado'], ['Domingo', 'Domingo']];
const bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
const localized = { Critico: 'Crítico', Guia: 'Guía', Cedula: 'Cédula' };

function node(tag, value, className) {
  const item = document.createElement(tag);
  if (value !== undefined) item.textContent = value;
  if (className) item.className = className;
  return item;
}

function button(label, action, className) {
  const item = node('button', label, className);
  item.type = 'button';
  item.addEventListener('click', action);
  return item;
}

function feedback(id, message = '', error = false) {
  const item = byId(id);
  item.textContent = message;
  item.dataset.error = String(error);
}

async function request(path, method = 'GET', body) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    const detail = Array.isArray(data.detail) ? data.detail.map((item) => item.msg).join(' ') : data.detail;
    throw new Error(detail || 'La operación no pudo completarse.');
  }
  return response;
}

async function json(path, method, body) {
  return (await request(path, method, body)).json();
}

function options(values) {
  return values.map((value) => Array.isArray(value) ? value : [value, value]);
}

function field(name, label, type = 'text', attrs = {}) {
  const wrap = node('label', undefined, attrs.wide ? 'wide' : undefined);
  const caption = node('span', label);
  caption.id = 'campo-m3-' + ++fieldNumber;
  const input = node(type === 'select' ? 'select' : type === 'textarea' ? 'textarea' : 'input');
  input.name = name;
  input.setAttribute('aria-labelledby', caption.id);
  if (type === 'select') {
    if (!attrs.multiple) input.add(new Option(attrs.placeholder || 'Selecciona una opción', ''));
    for (const [value, text] of options(attrs.options || [])) input.add(new Option(text, value));
    input.multiple = Boolean(attrs.multiple);
  } else if (type === 'textarea') {
    input.rows = 3;
    input.maxLength = 3000;
  } else {
    input.type = type;
    if (type === 'number') {
      input.min = attrs.min ?? '0';
      input.step = attrs.step ?? '1';
      if (attrs.max) input.max = attrs.max;
    }
    if (type === 'text') input.maxLength = attrs.maxLength || 150;
    if (type === 'password') {
      input.minLength = 10;
      input.maxLength = 128;
      input.autocomplete = 'new-password';
    }
  }
  input.required = Boolean(attrs.required);
  input.disabled = Boolean(attrs.disabled);
  if (attrs.value !== undefined && attrs.value !== null) {
    if (input.multiple) {
      for (const item of input.options) item.selected = attrs.value.map(String).includes(item.value);
    } else {
      input.value = String(attrs.value);
    }
  }
  wrap.append(caption, input);
  return { wrap, input };
}

const listOptions = (rows, id, caption) => rows.map((row) => [row[id], row[caption]]);
const territorialOptions = (rows, id, caption) => rows.map((row) => {
  const territory = [row.cod_estado, row.cod_municipio, row.cod_parroquia].filter(Boolean).join(' / ');
  const context = [row.tipo, territory].filter(Boolean).join(' · ');
  return [row[id], row[caption] + (context ? ' (' + context + ')' : '')];
});
const routeKey = (row) => JSON.stringify([row.cod_estado, row.cod_municipio, row.nombre_ruta]);
const hitoKey = (row) => JSON.stringify([row.cod_estado, row.cod_municipio, row.cod_parroquia, row.nombre_hito]);
const routeValues = (key) => {
  const [cod_estado, cod_municipio, nombre_ruta] = JSON.parse(key);
  return { cod_estado, cod_municipio, nombre_ruta };
};
const hitoValues = (key) => {
  const [cod_estado, cod_municipio, cod_parroquia, nombre_hito] = JSON.parse(key);
  return { cod_estado, cod_municipio, cod_parroquia, nombre_hito };
};
const routesOptions = () => catalogs.rutas.map((row) => [routeKey(row), row.nombre_ruta + ' (' + row.cod_estado + ' / ' + row.cod_municipio + ')']);
const landmarks = () => catalogs.afectables.filter((row) => row.tipo === 'Hito').map((row) => [
  hitoKey(row), row.nombre_hito + ' (' + row.cod_estado + ' / ' + row.cod_municipio + ')',
]);

const incidentColumns = [['nro_reporte', 'Reporte'], ['elemento', 'Elemento'], ['severidad', 'Severidad'],
  ['estado_efectivo', 'Estado'], ['fecha_hora_deteccion', 'Detectado'], ['fecha_limite', 'Fecha límite']];
const passColumns = [['cod_verificacion', 'Código'], ['servicio', 'Servicio'], ['fecha_hora_visita', 'Visita'],
  ['estado_efectivo', 'Estado'], ['validador', 'Validador']];
const incidentFilters = () => [
  field('q', 'Buscar', 'search'), field('estado', 'Estado', 'select', { options: incidentStates, placeholder: 'Todos' }),
  field('severidad', 'Severidad', 'select', { options: severities, placeholder: 'Todas' }),
  field('tipo_elemento', 'Elemento', 'select', { options: ['Hito', 'Tramo'], placeholder: 'Todos' }),
  field('desde', 'Desde', 'date'), field('hasta', 'Hasta', 'date'),
];

const sections = {
  experiencias: {
    label: 'Experiencias', caption: 'Consulta promociones vigentes y los servicios incluidos en cada recorrido.',
    columns: [['titulo', 'Experiencia'], ['nombre_ruta', 'Ruta'], ['comercio', 'Comercio'], ['precio_total', 'Precio'],
      ['cupo_maximo', 'Cupo'], ['fecha_vencimiento', 'Vence']],
    filters: () => [
      field('q', 'Buscar', 'search'), field('ruta', 'Ruta', 'select', { options: routesOptions(), placeholder: 'Todas' }),
      field('vigente', 'Vigencia', 'select', { options: [['true', 'Vigentes'], ['false', 'Fuera de vigencia']], placeholder: 'Todas' }),
      field('precio_max', 'Precio máximo', 'number', { step: '.01' }),
    ],
    detail: (row) => '/experiencias/' + row.fecha_activacion + '/' + encodeURIComponent(row.titulo),
    create: () => editorExperience(),
    canCreate: () => hasRole('Comercio', 'Admin') && catalogs.rutas_disponibles,
    createLabel: 'Registrar experiencia',
    empty: () => catalogs.rutas_disponibles ? 'No hay experiencias con estos filtros.' : 'Las experiencias se habilitan al cargar las rutas del módulo 2.',
  },
  credenciales: {
    label: 'Credenciales', caption: 'Emite, consulta y verifica pases para hitos y servicios.',
    roles: ['Visitante', 'Guia', 'Comercio', 'Admin'], columns: passColumns,
    filters: () => [
      field('q', 'Código, servicio o validador', 'search'),
      field('estado', 'Estado', 'select', { options: passStates, placeholder: 'Todos' }),
      field('tipo_servicio', 'Servicio', 'select', { options: ['Hito', 'Comercio'], placeholder: 'Todos' }),
      field('desde', 'Visita desde', 'date'), field('hasta', 'Visita hasta', 'date'),
    ],
    detail: (row) => '/credenciales/' + encodeURIComponent(row.cod_verificacion),
    create: () => editorPass(),
    canCreate: () => hasRole('Visitante'), createLabel: 'Emitir credencial',
  },
  incidencias: {
    label: 'Incidencias', caption: 'Reporta obstáculos y consulta el estado de atención.',
    columns: incidentColumns, filters: incidentFilters, detail: (row) => '/incidencias/' + row.nro_reporte,
    create: () => editorIncident(),
    canCreate: () => hasRole('Visitante', 'Guia', 'Ente', 'Admin'), createLabel: 'Reportar incidencia',
  },
  bandeja: {
    label: 'Bandeja institucional', caption: 'Reportes preliminares pendientes de verificación para tu ente.',
    roles: ['Ente', 'Admin'], path: '/incidencias/bandeja', columns: incidentColumns,
    filters: () => [field('solo_visitantes', 'Origen del reporte', 'select', {
      options: [['true', 'Visitantes que reportan hitos']], placeholder: 'Todos',
    })],
    detail: (row) => '/incidencias/' + row.nro_reporte,
  },
  evaluaciones: {
    label: 'Evaluaciones', caption: 'Consulta calificaciones y opiniones respaldadas por una visita o un recorrido.',
    columns: [['objeto', 'Ruta o hito'], ['visitante', 'Visitante'], ['calificacion', 'Calificación'],
      ['indice_seguridad', 'Seguridad'], ['fecha_emision', 'Publicada']],
    filters: () => [
      field('q', 'Buscar', 'search'), field('ruta', 'Ruta', 'select', { options: routesOptions(), placeholder: 'Todas' }),
      field('tipo_objeto', 'Tipo de lugar', 'select', { options: ['Hito', 'Ruta'], placeholder: 'Todos' }),
      field('calificacion_min', 'Calificación mínima', 'number', { min: 1, max: 5 }),
    ],
    detail: (row) => '/evaluaciones/' + encodeURIComponent(row.cod_resena),
    create: () => editorReview(), canCreate: () => hasRole('Visitante'), createLabel: 'Publicar evaluación',
  },
  observatorio: {
    label: 'Observatorio', caption: 'Prioriza incidencias críticas y revisa los plazos de respuesta institucional.',
    roles: ['Ente', 'Admin'],
    columns: [...incidentColumns, ['id_reportante', 'ID reportante'], ['ente_confirma', 'Confirma', false], ['ente_cierra', 'Cierra', false]],
    filters: incidentFilters, detail: (row) => '/incidencias/' + row.nro_reporte,
  },
  actores: {
    label: 'Actores', caption: 'Administra las cuentas y los perfiles de acceso a la plataforma.',
    roles: ['Admin'],
    columns: [['id_usuario', 'ID'], ['nombre', 'Nombre'], ['tipo_actor', 'Perfil'], ['identificador', 'Identificador']],
    filters: () => [field('q', 'Buscar por nombre o identificador', 'search'),
      field('tipo_actor', 'Perfil', 'select', { options: Object.entries(actorLabels).slice(0, 4), placeholder: 'Todos' })],
    detail: (row) => '/actores/' + row.id_usuario,
    create: () => editorActor(), canCreate: () => true, createLabel: 'Registrar actor',
  },
};

function hasRole(...roles) {
  return roles.includes(profile?.perfil);
}

function visibleSections() {
  return Object.entries(sections).filter(([, data]) => !data.roles || hasRole(...data.roles));
}

function format(value, key) {
  if (value === null || value === undefined || value === '') return '—';
  if (key.startsWith('fecha') && typeof value === 'string') {
    const [day, time] = value.split('T');
    return day.split('-').reverse().join('/') + (time ? ' ' + time.slice(0, 5) : '');
  }
  if (typeof value === 'boolean') return value ? 'Sí' : 'No';
  return Object.hasOwn(localized, value) ? localized[value] : String(value);
}

function selectSection(key) {
  section = key;
  page = 1;
  sort = '';
  direction = 'asc';
  byId('results').replaceChildren();
  byId('pagination').replaceChildren();
  byId('indicators').hidden = true;
  const data = sections[key];
  renderSections();
  byId('section-title').textContent = data.label;
  byId('section-caption').textContent = data.caption;
  const actions = byId('section-actions');
  actions.replaceChildren();
  if (data.canCreate?.()) actions.append(button(data.createLabel, data.create));
  if (key === 'credenciales') {
    actions.append(button('Verificar código', verifyCode, 'outline'));
    if (hasRole('Visitante', 'Admin')) actions.append(button('Credenciales emitidas', issuedPasses, 'outline'));
  }
  if (key === 'observatorio') actions.append(button('Descargar CSV', downloadReport, 'outline'));
  const run = node('button', 'Filtrar');
  run.type = 'submit';
  byId('filters').replaceChildren(...data.filters().map((item) => item.wrap), run);
  loadPage();
}

function renderSections() {
  byId('sections').replaceChildren(...visibleSections().map(([name, item]) => {
    const control = button(item.label, () => selectSection(name));
    if (name === section) control.setAttribute('aria-current', 'page');
    if (name === 'bandeja' && pendingIncidents > 0) {
      control.append(node('span', pendingIncidents, 'pending-count'));
      control.setAttribute('aria-label', item.label + ', ' + pendingIncidents + ' pendientes');
    }
    return control;
  }));
}

async function refreshPending() {
  if (!hasRole('Ente', 'Admin')) return;
  const session = token;
  try {
    const result = await json(api + '/incidencias/bandeja?page_size=1');
    if (token === session && result.total !== pendingIncidents) {
      pendingIncidents = result.total;
      renderSections();
    }
  } catch {
    // La bandeja informa su propio error cuando se abre.
  }
}

function queryFilters() {
  const query = new URLSearchParams();
  for (const [key, value] of new FormData(byId('filters'))) {
    if (value) query.set(key, value);
  }
  if (query.has('ruta')) {
    for (const [key, value] of Object.entries(routeValues(query.get('ruta')))) query.set(key, value);
    query.delete('ruta');
  }
  return query;
}

function renderIndicators(values, quality = false) {
  const zone = byId('indicators');
  const entries = quality ? [
    ['Evaluaciones de la ruta', values.total], ['Calificación promedio', values.calificacion_promedio],
    ['Seguridad promedio', values.seguridad_promedio],
  ] : [
    ['Incidencias activas', values.activas], ['Incidencias críticas', values.porcentaje_criticas + '%'],
    ['Prórrogas vigentes', values.prorrogas_activas], ['Horas promedio de confirmación', values.horas_promedio_confirmacion],
    ['Horas promedio de cierre', values.horas_promedio_cierre],
  ];
  zone.replaceChildren(...entries.map(([label, value]) => {
    const box = node('div', undefined, 'indicator');
    box.append(node('strong', value ?? '—'), node('span', label));
    return box;
  }));
  zone.hidden = false;
}

async function loadPage() {
  const sequence = ++requestNumber;
  const data = sections[section];
  const query = queryFilters();
  query.set('page', page);
  query.set('sort_dir', direction);
  if (sort) query.set('sort_by', sort);
  feedback('feedback', 'Cargando registros…');
  byId('results').setAttribute('aria-busy', 'true');
  try {
    const result = await json(api + (data.path || '/' + section) + '?' + query);
    if (sequence !== requestNumber) return;
    if (page > result.total_pages) {
      page = result.total_pages;
      return loadPage();
    }
    byId('indicators').hidden = true;
    if (result.indicadores) renderIndicators(result.indicadores);
    if (section === 'evaluaciones' && query.has('nombre_ruta')) {
      const routeQuery = new URLSearchParams();
      for (const key of ['cod_estado', 'cod_municipio', 'nombre_ruta']) routeQuery.set(key, query.get(key));
      const quality = await json(api + '/calidad-ruta?' + routeQuery);
      if (sequence !== requestNumber) return;
      renderIndicators(quality, true);
    }
    renderTable(result, data);
    feedback('feedback');
  } catch (error) {
    if (sequence === requestNumber) feedback('feedback', error.message, true);
  } finally {
    if (sequence === requestNumber) byId('results').setAttribute('aria-busy', 'false');
  }
}

function renderTable(result, data) {
  const box = byId('results');
  const pager = byId('pagination');
  pager.replaceChildren();
  if (!result.items.length) {
    box.replaceChildren(node('p', data.empty?.() || 'No hay registros con estos filtros.', 'empty'));
    return;
  }
  const table = node('table');
  table.setAttribute('aria-label', data.label);
  const head = table.createTHead().insertRow();
  for (const [key, label, sortable = true] of data.columns) {
    const header = node('th');
    header.scope = 'col';
    if (!sortable) header.textContent = label;
    else {
      const marker = result.sort_by === key ? (result.sort_dir === 'asc' ? ' ▲' : ' ▼') : '';
      if (marker) header.setAttribute('aria-sort', result.sort_dir === 'asc' ? 'ascending' : 'descending');
      header.append(button(label + marker, () => {
        direction = result.sort_by === key && result.sort_dir === 'asc' ? 'desc' : 'asc';
        sort = key;
        page = 1;
        loadPage();
      }, 'link'));
    }
    head.append(header);
  }
  const body = table.createTBody();
  for (const row of result.items) {
    const line = body.insertRow();
    data.columns.forEach(([key], index) => {
      const cell = line.insertCell();
      const text = format(row[key], key);
      if (index === 0) cell.append(button(text, () => openRecord(data.detail(row)), key === 'cod_verificacion' ? 'link pass-code' : 'link'));
      else if (key === 'estado_efectivo' || key === 'severidad') {
        const tag = node('span', text, 'tag');
        tag.dataset.value = row[key];
        cell.append(tag);
      } else cell.textContent = text;
    });
  }
  box.replaceChildren(table);
  const controls = node('div', undefined, 'actions');
  const previous = button('Anterior', () => { page--; loadPage(); }, 'outline');
  previous.disabled = page === 1;
  const next = button('Siguiente', () => { page++; loadPage(); }, 'outline');
  next.disabled = page === result.total_pages;
  controls.append(previous, next);
  pager.append(node('span', result.total + ' registros · Página ' + page + ' de ' + result.total_pages), controls);
}

function showDialog(title, items, action, submitLabel = 'Guardar cambios') {
  editorAction = action;
  byId('dialog-title').textContent = title;
  byId('dialog-body').replaceChildren(...items);
  byId('dialog-actions').replaceChildren();
  feedback('dialog-feedback');
  if (action) {
    const submit = node('button', submitLabel);
    submit.type = 'submit';
    byId('dialog-actions').append(submit);
  }
  if (!byId('dialog').open) byId('dialog').showModal();
  else byId('dialog-title').focus();
}

function formFields(definitions, data = {}) {
  return definitions.map(([name, label, type, attrs]) => field(name, label, type, {
    required: true, ...attrs, value: data[name],
  }));
}

function readInput(input) {
  if (input.multiple) return Array.from(input.selectedOptions, (option) => option.value);
  if (input.type === 'number') return input.value === '' ? null : Number(input.value);
  if (input.type === 'password') return input.value || null;
  return input.value.trim() || null;
}

function readFields(fields) {
  return Object.fromEntries(fields.map(({ input }) => [input.name, readInput(input)]));
}

function repeater(title, definitions, entries, minCount = 0) {
  const group = node('fieldset', undefined, 'wide');
  group.append(node('legend', title));
  const rows = node('div');
  const add = button('Agregar', () => append(), 'outline');
  group.append(rows, add);
  const fields = [];
  function append(data) {
    const list = formFields(definitions, data);
    const row = node('div', undefined, 'repeat-item');
    const remove = button('Quitar', () => {
      if (fields.length <= minCount) return;
      fields.splice(fields.indexOf(list), 1);
      row.remove();
    }, 'outline');
    row.append(...list.map((item) => item.wrap), remove);
    fields.push(list);
    rows.append(row);
  }
  for (const entry of entries || []) append(entry);
  if (minCount && !fields.length) append();
  return { group, values: () => fields.map(readFields) };
}

function detailList(row, fields) {
  const list = node('dl', undefined, 'detail wide');
  for (const [key, label] of fields) {
    const line = node('div');
    line.append(node('dt', label), node('dd', format(row[key], key)));
    list.append(line);
  }
  return list;
}

async function commit(path, method, body, message) {
  await request(api + path, method, body);
  byId('dialog').close();
  await loadPage();
  feedback('feedback', message);
  if (path.startsWith('/incidencias')) refreshPending();
}

function pair(label, action, className = 'outline') {
  byId('dialog-actions').append(button(label, action, className));
}

function confirmRemoval(path, label) {
  showDialog(label, [node('p', 'Confirma el borrado de este registro.', 'wide')],
    () => commit(path, 'DELETE', undefined, 'Registro eliminado.'), 'Eliminar');
}

async function openRecord(path) {
  try {
    const data = await json(api + path);
    if (path.startsWith('/experiencias/')) return experienceDetail(path, data);
    if (path.startsWith('/credenciales/')) return passDetail(path, data);
    if (path.startsWith('/incidencias/')) return incidentDetail(path, data);
    if (path.startsWith('/evaluaciones/')) return reviewDetail(path, data);
    return actorDetail(path, data);
  } catch (error) {
    feedback(byId('dialog').open ? 'dialog-feedback' : 'feedback', error.message, true);
  }
}

function experienceDetail(path, row) {
  const services = node('ul', undefined, 'wide');
  for (const item of row.detalles) services.append(node('li', item.servicio + ' · ' + item.costo_individual));
  showDialog(row.titulo, [detailList(row, [
    ['descripcion', 'Descripción'], ['nombre_ruta', 'Ruta'], ['comercio', 'Comercio promotor'],
    ['guia_rtn', 'RTN del guía'], ['precio_total', 'Precio total'], ['cupo_maximo', 'Cupo'],
    ['porcentaje_descuento', 'Descuento (%)'], ['fecha_activacion', 'Activación'],
    ['fecha_vencimiento', 'Vencimiento'], ['codigo_promocional', 'Código promocional'],
  ]), node('h3', 'Servicios incluidos', 'wide'), services]);
  if (hasRole('Admin') || (hasRole('Comercio') && row.id_usuario_comercio === profile.id_usuario)) {
    pair('Editar', () => editorExperience(row, path));
    pair('Eliminar', () => confirmRemoval(path, 'Eliminar experiencia'), 'outline danger');
  }
}

function editorExperience(row, path = '/experiencias') {
  const entries = formFields([
    ['titulo', 'Título', 'text', { disabled: Boolean(row), maxLength: 160 }],
    ['fecha_activacion', 'Fecha de activación', 'date', { disabled: Boolean(row) }],
    ['descripcion', 'Descripción', 'textarea', { wide: true }],
    ['ruta', 'Ruta', 'select', { options: routesOptions() }],
    ['id_usuario_guia', 'Guía director', 'select', { options: listOptions(catalogs.guias, 'id_usuario', 'validador') }],
    ['precio_total', 'Precio total', 'number', { step: '.01' }], ['cupo_maximo', 'Cupo', 'number', { min: 1 }],
    ['porcentaje_descuento', 'Descuento (%)', 'number', { step: '.01', max: 100 }],
    ['fecha_vencimiento', 'Fecha de vencimiento', 'date'],
    ['codigo_promocional', 'Código promocional', 'text', { required: false, maxLength: 40 }],
  ], row ? { ...row, ruta: routeKey(row) } : {});
  if (hasRole('Admin')) entries.push(field('id_usuario_comercio', 'Comercio promotor', 'select', {
    options: listOptions(catalogs.comercios, 'id_usuario', 'validador'), required: true, value: row?.id_usuario_comercio,
  }));
  const services = repeater('Servicios incluidos', [
    ['id_elem_servicio', 'Servicio', 'select', { options: territorialOptions(catalogs.servicios, 'id_elem_servicio', 'servicio') }],
    ['costo_individual', 'Costo individual', 'number', { step: '.01' }],
  ], row?.detalles, 1);
  showDialog(row ? 'Editar experiencia' : 'Registrar experiencia', [...entries.map((item) => item.wrap), services.group], () => {
    const values = readFields(entries);
    const route = routeValues(values.ruta);
    delete values.ruta;
    return commit(path, row ? 'PUT' : 'POST', { ...values, ...route, detalles: services.values() }, 'Experiencia guardada.');
  });
}

function passDetail(path, row) {
  showDialog('Credencial ' + row.cod_verificacion, [detailList(row, [
    ['servicio', 'Servicio'], ['validador', 'Validador'], ['estado_efectivo', 'Estado'], ['fecha_hora_visita', 'Visita'],
    ['fecha_hora_canje', 'Canje'], ['cant_beneficiarios', 'Beneficiarios'], ['monto_abonado', 'Monto abonado'],
  ])]);
  byId('dialog-title').replaceChildren('Credencial ', node('code', row.cod_verificacion));
  if (row.canjeable && hasRole('Guia', 'Comercio')) {
    pair('Canjear credencial', () => showDialog('Canjear credencial', [node('p', row.servicio, 'wide')],
      () => commit(path + '/canjear', 'POST', undefined, 'Credencial canjeada.'), 'Canjear credencial'));
  }
  if (hasRole('Visitante') && row.id_usuario === profile.id_usuario && row.estado_efectivo === 'Emitido') {
    pair('Editar', () => editorPass(row, path));
    pair('Cancelar pase', () => showDialog('Cancelar pase', [node('p', 'Confirma la cancelación de la credencial.', 'wide')],
      () => commit(path + '/estado', 'POST', { estado_pase: 'Cancelado' }, 'Pase cancelado.'), 'Cancelar pase'));
    pair('Eliminar', () => confirmRemoval(path, 'Eliminar credencial'), 'outline danger');
  }
  if (hasRole('Visitante', 'Admin') && row.estado_efectivo === 'Vencido' && row.estado_pase === 'Emitido') {
    pair('Registrar vencimiento', () => showDialog('Registrar vencimiento', [node('p', 'La fecha de visita ya pasó.', 'wide')],
      () => commit(path + '/estado', 'POST', { estado_pase: 'Vencido' }, 'Vencimiento registrado.'), 'Registrar vencimiento'));
  }
}

function editorPass(row, path = '/credenciales') {
  const entries = formFields([
    ['id_elem_servicio', 'Hito o servicio', 'select', { options: territorialOptions(catalogs.servicios, 'id_elem_servicio', 'servicio') }],
    ['id_validador', 'Validador', 'select', { options: listOptions(catalogs.validadores, 'id_validador', 'validador') }],
    ['fecha_hora_visita', 'Fecha y hora en Caracas', 'datetime-local'],
    ['cant_beneficiarios', 'Beneficiarios', 'number', { min: 1 }],
    ['monto_abonado', 'Monto abonado', 'number', { step: '.01' }],
  ], row);
  showDialog(row ? 'Editar credencial' : 'Emitir credencial', entries.map((item) => item.wrap),
    () => commit(path, row ? 'PUT' : 'POST', readFields(entries), 'Credencial guardada.'));
}

function verifyCode() {
  const code = field('codigo', 'Código de verificación', 'text', { required: true, maxLength: 64 });
  showDialog('Verificar credencial', [code.wrap], () => openRecord('/credenciales/' + encodeURIComponent(code.input.value.trim())), 'Verificar código');
}

function issuedPasses() {
  async function display(userId) {
    const params = new URLSearchParams({ page_size: 100 });
    if (userId) params.set('id_usuario', userId);
    const data = await json(api + '/credenciales/emitidas?' + params);
    const list = node('ul', undefined, 'wide');
    for (const row of data.items) {
      const item = node('li');
      item.append(button(row.cod_verificacion + ' · ' + row.servicio + ' · ' + row.validador,
        () => openRecord(sections.credenciales.detail(row)), 'link'));
      list.append(item);
    }
    showDialog('Credenciales emitidas para hitos', [node('p', 'Total: ' + data.total, 'wide'), list]);
  }
  if (hasRole('Admin')) {
    const user = field('id_usuario', 'ID del visitante', 'number', { min: 1, required: true });
    showDialog('Credenciales emitidas para hitos', [user.wrap], () => display(user.input.value), 'Consultar');
  } else display().catch((error) => feedback('feedback', error.message, true));
}

function incidentDetail(path, row) {
  const items = [detailList(row, [
    ['elemento', 'Elemento afectado'], ['descripcion_evento', 'Descripción'], ['estado_efectivo', 'Estado'],
    ['severidad', 'Severidad'], ['tipo_reportante', 'Perfil reportante'], ['id_reportante', 'ID reportante'],
    ['fecha_hora_deteccion', 'Detectado'], ['fecha_estimada_resolucion', 'Fecha estimada inicial'], ['fecha_limite', 'Fecha límite'],
    ['ente_confirma', 'Ente que confirma'], ['fecha_confirmacion', 'Confirmación'],
    ['ente_cierra', 'Ente que cierra'], ['fecha_cierre', 'Cierre'],
  ])];
  if (row.prorrogas?.length) {
    const list = node('ul', undefined, 'wide');
    row.prorrogas.forEach((extension) => list.append(node('li',
      format(extension.nueva_fecha_estimada, 'fecha') + ' · ' + extension.justificacion)));
    items.push(node('h3', 'Prórrogas', 'wide'), list);
  }
  showDialog('Incidencia ' + row.nro_reporte, items);
  const authority = hasRole('Admin', 'Ente');
  if (row.estado_reporte === 'Preliminar') {
    if (authority) pair('Confirmar incidencia', () => incidentAction(path, 'confirmar', 'Confirmar incidencia', [
      ['severidad', 'Ratificar severidad', 'select', { options: severities }],
      ['nueva_fecha_estimada', 'Nueva fecha estimada', 'date', { required: false }],
    ], { severidad: row.severidad }, 'Incidencia confirmada.'));
    if (hasRole('Admin') || row.usuario_reportante === profile.id_usuario) {
      pair('Editar', () => editorIncident(row, path));
      pair('Eliminar', () => confirmRemoval(path, 'Eliminar incidencia'), 'outline danger');
    }
  }
  if (authority && row.estado_reporte === 'Activo' && row.id_usuario_confirma === profile.id_usuario) {
    pair('Registrar prórroga', () => incidentAction(path, 'prorrogar', 'Registrar prórroga', [
      ['nueva_fecha_estimada', 'Nueva fecha estimada', 'date'], ['justificacion', 'Justificación', 'textarea', { wide: true }],
    ], {}, 'Prórroga registrada.'));
    pair('Cerrar incidencia', () => showDialog('Cerrar incidencia', [node('p', 'Confirma que el obstáculo fue resuelto.', 'wide')],
      () => commit(path + '/cerrar', 'POST', undefined, 'Incidencia cerrada.'), 'Cerrar incidencia'));
  }
}

function incidentAction(path, key, title, definitions, values, message) {
  const entries = formFields(definitions, values);
  showDialog(title, entries.map((item) => item.wrap), () => commit(path + '/' + key, 'POST', readFields(entries), message), title);
}

function editorIncident(row, path = '/incidencias') {
  const entries = formFields([
    ['id_elem_afectable', 'Elemento afectado', 'select', { options: territorialOptions(catalogs.afectables, 'id_elem_afectable', 'elemento') }],
    ['severidad', 'Severidad', 'select', { options: severities }],
    ['fecha_estimada_resolucion', 'Fecha estimada de resolución', 'date'],
    ['descripcion_evento', 'Descripción', 'textarea', { wide: true }],
  ], row);
  if (!row) entries.unshift(field('fecha_hora_deteccion', 'Fecha y hora de detección en Caracas', 'datetime-local', { required: true }));
  showDialog(row ? 'Editar incidencia' : 'Reportar incidencia', entries.map((item) => item.wrap),
    () => commit(path, row ? 'PUT' : 'POST', readFields(entries), 'Incidencia guardada.'));
}

function reviewDetail(path, row) {
  showDialog('Evaluación de ' + row.objeto, [detailList(row, [
    ['visitante', 'Visitante'], ['fecha_emision', 'Publicada'], ['calificacion', 'Calificación'],
    ['indice_seguridad', 'Seguridad'], ['opinion', 'Opinión'], ['recorrido_verificado', 'Visita verificada'],
  ])]);
  if (hasRole('Visitante') && row.id_usuario === profile.id_usuario) {
    pair('Editar', () => editorReview(row, path));
    pair('Eliminar', () => confirmRemoval(path, 'Eliminar evaluación'), 'outline danger');
  }
}

function editorReview(row, path = '/evaluaciones') {
  const entries = formFields([
    ['calificacion', 'Calificación (1 a 5)', 'number', { min: 1, max: 5 }],
    ['indice_seguridad', 'Seguridad (1 a 5)', 'number', { min: 1, max: 5 }],
    ['opinion', 'Opinión', 'textarea', { wide: true }],
  ], row);
  if (!row) entries.unshift(field('id_obj_evaluable', 'Ruta o hito', 'select', { required: true,
    options: territorialOptions(catalogs.evaluables, 'id_obj_evaluable', 'objeto'),
  }));
  showDialog(row ? 'Editar evaluación' : 'Publicar evaluación', entries.map((item) => item.wrap),
    () => commit(path, row ? 'PUT' : 'POST', readFields(entries), 'Evaluación guardada.'));
}

const actorFields = {
  Visitante: [
    ['nombres', 'Nombres', 'text', { maxLength: 100 }], ['apellidos', 'Apellidos', 'text', { maxLength: 100 }],
    ['tipo_documento', 'Tipo de documento', 'select', { options: [['Cedula', 'Cédula'], 'Pasaporte'] }],
    ['doc_identidad', 'Número de documento', 'text', { maxLength: 30 }],
    ['pais_origen', 'País de origen', 'text', { maxLength: 80 }], ['idioma_nativo', 'Idioma nativo', 'text', { maxLength: 60 }],
    ['tel_emergencia', 'Teléfono de emergencia', 'text', { maxLength: 30 }],
    ['grupo_sanguineo', 'Grupo sanguíneo', 'select', { options: bloodGroups }],
  ],
  Guia: [
    ['nro_rtn', 'Registro turístico nacional', 'text', { maxLength: 30 }], ['cod_licencia', 'Licencia', 'text', { maxLength: 30 }],
    ['acreditacion_oficial', 'Acreditación oficial', 'text', { maxLength: 200 }],
    ['anios_trayectoria', 'Años de trayectoria', 'number'], ['tarifa_hora', 'Tarifa por hora', 'number', { min: '.01', step: '.01' }],
    ['zona_asignada', 'Zona asignada', 'text'],
  ],
  Comercio: [
    ['rif_comercio', 'RIF', 'text', { maxLength: 20 }], ['razon_social', 'Razón social', 'text'],
    ['categoria_comercial', 'Categoría comercial', 'text', { maxLength: 80 }],
    ['aforo', 'Aforo', 'number', { min: 1 }], ['nro_permiso_sanitario', 'Permiso sanitario', 'text', { maxLength: 40 }],
    ['cuenta_bancaria', 'Cuenta bancaria', 'text', { maxLength: 34 }],
  ],
  Ente: [
    ['rif_institucional', 'RIF institucional', 'text', { maxLength: 20 }], ['denominacion_oficial', 'Denominación oficial', 'text'],
    ['nivel_territorial', 'Nivel territorial', 'select', { options: ['Nacional', 'Estadal', 'Municipal', 'Parroquial'] }],
    ['funcionario_enlace', 'Funcionario de enlace', 'text'], ['decreto_adscripcion', 'Decreto de adscripción', 'text', { maxLength: 100 }],
  ],
};

function actorDetail(path, row) {
  const description = actorFields[row.tipo_actor].map(([key, label]) => [key, label]);
  const related = [
    ['accesibilidades', 'Accesibilidad', row.accesibilidades],
    ['especialidades', 'Especialidades', row.especialidades],
    ['idiomas', 'Idiomas', row.idiomas],
    ['rutas', 'Rutas adscritas', row.rutas?.map((route) => route.nombre_ruta)],
    ['hito', 'Hito asociado', row.hito ? [row.hito.nombre_hito] : []],
    ['horarios', 'Horarios', row.horarios?.map((turn) => turn.dia + ' ' + turn.apertura.slice(0, 5) + '–' + turn.cierre.slice(0, 5))],
    ['tutelas', 'Hitos bajo tutela', row.tutelas?.map((hito) => hito.nombre_hito)],
  ].filter(([, , values]) => values);
  const display = { ...row };
  for (const [key, label, values] of related) {
    description.push([key, label]);
    display[key] = values.join(', ');
  }
  showDialog(actorLabels[row.tipo_actor] + ' · ' + row.id_usuario, [detailList(display, description)]);
  pair('Editar perfil', () => editorActor(row, path));
  if (row.id_usuario !== profile.id_usuario) pair('Eliminar', () => confirmRemoval(path, 'Eliminar actor'), 'outline danger');
}

function editorActor(row, path = '/actores', kind = row?.tipo_actor || 'Visitante') {
  const type = field('tipo_actor', 'Perfil', 'select', { options: Object.entries(actorLabels).slice(0, 4),
    required: true, value: kind, disabled: Boolean(row),
  });
  type.input.addEventListener('change', () => {
    if (type.input.value) editorActor(row, path, type.input.value);
  });
  const entries = formFields([
    ...actorFields[kind], ['contrasena', row ? 'Nueva contraseña (opcional)' : 'Contraseña', 'password', { required: !row }],
  ], row);
  const extras = [];
  const related = {};
  const addRepeatedText = (key, label, name, maxLength) => {
    const group = repeater(label, [[key, name, 'text', { maxLength }]], row?.[key]?.map((value) => ({ [key]: value })));
    related[key] = () => group.values().map((entry) => entry[key]);
    extras.push(group.group);
  };
  if (kind === 'Visitante') addRepeatedText('accesibilidades', 'Necesidades de accesibilidad', 'Necesidad', 120);
  if (kind === 'Guia') {
    addRepeatedText('especialidades', 'Especialidades', 'Especialidad', 100);
    addRepeatedText('idiomas', 'Idiomas', 'Idioma', 60);
    const routes = field('rutas', 'Rutas adscritas', 'select', { options: routesOptions(), multiple: true, value: row?.rutas?.map(routeKey) });
    related.rutas = () => readInput(routes.input).map(routeValues);
    extras.push(routes.wrap);
  }
  if (kind === 'Comercio') {
    const hito = field('hito', 'Hito asociado', 'select', { options: landmarks(), value: row?.hito ? hitoKey(row.hito) : undefined });
    const schedules = repeater('Horarios de atención', [
      ['dia', 'Día', 'select', { options: weekdays }], ['apertura', 'Apertura', 'time'], ['cierre', 'Cierre', 'time'],
    ], row?.horarios);
    related.hito = () => hito.input.value ? hitoValues(hito.input.value) : null;
    related.horarios = schedules.values;
    extras.push(hito.wrap, schedules.group);
  }
  if (kind === 'Ente') {
    const guardians = field('tutelas', 'Hitos bajo tutela', 'select', { options: landmarks(), multiple: true, value: row?.tutelas?.map(hitoKey) });
    related.tutelas = () => readInput(guardians.input).map(hitoValues);
    extras.push(guardians.wrap);
  }
  showDialog(row ? 'Editar actor' : 'Registrar actor', [type.wrap, ...entries.map((item) => item.wrap), ...extras], async () => {
    const relations = Object.fromEntries(Object.entries(related).map(([key, read]) => [key, read()]));
    await commit(path, row ? 'PUT' : 'POST', { tipo_actor: kind, ...readFields(entries), ...relations }, 'Actor guardado.');
    catalogs = await json(api + '/catalogos');
  });
}

async function downloadReport() {
  try {
    const response = await request(api + '/observatorio.csv?' + queryFilters());
    const url = URL.createObjectURL(await response.blob());
    const link = node('a');
    link.href = url;
    link.download = 'observatorio-incidencias.csv';
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  } catch (error) {
    feedback('feedback', error.message, true);
  }
}

function syncLogin() {
  const kind = byId('actor-type').value;
  byId('identifier-label').textContent = kind === 'Visitante' ? 'Número de documento' : kind === 'Guia' ? 'Registro turístico nacional' : 'RIF';
  byId('document-label').hidden = kind !== 'Visitante';
  byId('license-label').hidden = kind !== 'Guia';
  byId('login-form').elements.licencia.required = kind === 'Guia';
}

async function startSession(user) {
  catalogs = await json(api + '/catalogos');
  profile = user;
  byId('user').textContent = profile.nombre + ' · ' + actorLabels[profile.perfil];
  byId('login').hidden = true;
  byId('workspace').hidden = false;
  byId('session').hidden = false;
  const initial = { Visitante: 'experiencias', Guia: 'credenciales', Comercio: 'experiencias', Ente: 'bandeja', Admin: 'observatorio' };
  selectSection(initial[profile.perfil]);
  refreshPending();
}

function endSession() {
  requestNumber++;
  sessionStorage.removeItem(sessionKey);
  token = null;
  profile = null;
  pendingIncidents = 0;
  byId('workspace').hidden = true;
  byId('session').hidden = true;
  byId('dialog').close();
  byId('login').hidden = false;
  feedback('login-status');
}

byId('actor-type').addEventListener('change', syncLogin);
syncLogin();
byId('logout').addEventListener('click', endSession);
byId('close-dialog').addEventListener('click', () => byId('dialog').close());
byId('filters').addEventListener('submit', (event) => {
  event.preventDefault();
  page = 1;
  loadPage();
});
byId('editor').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!editorAction || !event.submitter) return;
  event.submitter.disabled = true;
  feedback('dialog-feedback');
  try {
    await editorAction();
  } catch (error) {
    feedback(byId('dialog').open ? 'dialog-feedback' : 'feedback', error.message, true);
  } finally {
    event.submitter.disabled = false;
  }
});
byId('login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  event.submitter.disabled = true;
  feedback('login-status');
  const form = new FormData(event.currentTarget);
  const kind = form.get('tipo_actor');
  try {
    const result = await json('/api/auth/login', 'POST', {
      tipo_actor: kind, identificador: form.get('identificador'),
      complemento: kind === 'Visitante' ? form.get('documento') : kind === 'Guia' ? form.get('licencia') : null,
      contrasena: form.get('contrasena'),
    });
    token = result.access_token;
    sessionStorage.setItem(sessionKey, token);
    await startSession(result.usuario);
    byId('login-form').elements.contrasena.value = '';
  } catch (error) {
    endSession();
    feedback('login-status', error.message, true);
  } finally {
    event.submitter.disabled = false;
  }
});

if (token) json('/api/auth/me').then(startSession).catch(endSession);

export { selectSection };
