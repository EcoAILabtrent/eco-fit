const state = {
  foods: [],
  filtered: [],
  rendered: 0,
  batchSize: 60,
  total: 0,
  current: null,
  imageFile: null,
  initialForm: "",
  saveInProgress: false,
};

// code -> input element, plus the macro json-key inputs.
const macroInputs = {};
const microInputs = {};

const elements = {
  grid: document.querySelector("#food-grid"),
  loading: document.querySelector("#loading"),
  empty: document.querySelector("#empty"),
  sentinel: document.querySelector("#load-sentinel"),
  search: document.querySelector("#search-input"),
  fillFilter: document.querySelector("#fill-filter"),
  categoryFilter: document.querySelector("#category-filter"),
  visibleCount: document.querySelector("#visible-count"),
  totalLabel: document.querySelector("#total-label"),
  scrollTop: document.querySelector("#scroll-top"),
  cardTemplate: document.querySelector("#card-template"),
  fieldTemplate: document.querySelector("#nutrient-field-template"),
  macroFields: document.querySelector("#macro-fields"),
  mineralFields: document.querySelector("#mineral-fields"),
  vitaminFields: document.querySelector("#vitamin-fields"),
  dialog: document.querySelector("#editor-dialog"),
  form: document.querySelector("#editor-form"),
  editorTitle: document.querySelector("#editor-title"),
  editorSlug: document.querySelector("#editor-slug"),
  editorImage: document.querySelector("#editor-image"),
  editorImageEmpty: document.querySelector("#editor-image-empty"),
  imageInput: document.querySelector("#image-input"),
  categoryInput: document.querySelector("#category-input"),
  nameInputs: {
    uz_latn: document.querySelector("#name-uz-latn"),
    uz_cyrl: document.querySelector("#name-uz-cyrl"),
    ru: document.querySelector("#name-ru"),
    en: document.querySelector("#name-en"),
  },
  closeEditor: document.querySelector("#close-editor"),
  cancelEditor: document.querySelector("#cancel-editor"),
  clearEditor: document.querySelector("#clear-editor"),
  saveEditor: document.querySelector("#save-editor"),
  saveStatus: document.querySelector("#save-status"),
  toast: document.querySelector("#toast"),
};

function normalized(value) {
  return String(value ?? "").toLocaleLowerCase().replace(/ё/g, "е").trim();
}

function searchableText(food) {
  return normalized([food.slug, food.category, food.emoji, ...Object.values(food.names)].join(" "));
}

// "" -> blank; "3,5" -> {value:3.5}; "-1" -> {invalid}
function parseAmount(text) {
  const trimmed = String(text ?? "").trim().replace(",", ".");
  if (trimmed === "") return { empty: true };
  const value = Number(trimmed);
  if (!Number.isFinite(value) || value < 0) return { invalid: true };
  return { value };
}

function displayAmount(value) {
  if (value === null || value === undefined || value === "") return "";
  return String(value);
}

function fillBucket(food) {
  if (!food.filled) return "empty";
  if (food.filled >= food.total) return "full";
  return "partial";
}

function populateCategories() {
  const categories = [...new Set(state.foods.map((food) => food.category).filter(Boolean))]
    .sort((a, b) => a.localeCompare(b, "uz"));
  const fragment = document.createDocumentFragment();
  for (const category of categories) {
    const option = document.createElement("option");
    option.value = category;
    option.textContent = category;
    fragment.append(option);
  }
  elements.categoryFilter.append(fragment);
}

function updateCount() {
  elements.visibleCount.textContent = state.filtered.length.toLocaleString("ru-RU");
  elements.totalLabel.textContent = `из ${state.foods.length.toLocaleString("ru-RU")} продуктов`;
}

function applyFilters() {
  const query = normalized(elements.search.value);
  const fillMode = elements.fillFilter.value;
  const category = elements.categoryFilter.value;
  state.filtered = state.foods.filter((food) => {
    if (query && !searchableText(food).includes(query)) return false;
    if (category !== "all" && food.category !== category) return false;
    if (fillMode !== "all" && fillBucket(food) !== fillMode) return false;
    return true;
  });
  state.rendered = 0;
  elements.grid.replaceChildren();
  updateCount();
  elements.empty.hidden = state.filtered.length !== 0;
  appendBatch();
}

function createCard(food) {
  const card = elements.cardTemplate.content.firstElementChild.cloneNode(true);
  card.dataset.slug = food.slug;
  const title = food.names.ru || food.names.uz_latn || food.slug;
  card.setAttribute("aria-label", `Редактировать: ${title}`);

  const image = card.querySelector(".card-image");
  const imageEmpty = card.querySelector(".card-image-empty");
  if (food.image_url) {
    image.src = food.image_url;
    image.alt = title;
    imageEmpty.hidden = true;
  } else {
    image.hidden = true;
  }

  card.querySelector(".card-category").textContent = food.category || "Без категории";

  const pill = card.querySelector(".fill-pill");
  const bucket = fillBucket(food);
  pill.classList.add(bucket);
  pill.textContent = `${food.filled}/${food.total}`;

  card.querySelector(".card-emoji").textContent = food.emoji || "";
  card.querySelector(".card-name").textContent = title;

  const sub = [food.names.uz_latn, food.names.en].filter((name) => name && name !== title).join(" · ");
  card.querySelector(".card-sub").textContent = sub || food.slug;

  card.querySelector(".fill-bar i").style.width = `${Math.round((food.filled / food.total) * 100)}%`;
  card.querySelector(".card-slug").textContent = food.slug;

  card.addEventListener("click", () => openEditor(food.slug));
  return card;
}

function appendBatch() {
  if (state.rendered >= state.filtered.length) return;
  const end = Math.min(state.rendered + state.batchSize, state.filtered.length);
  const fragment = document.createDocumentFragment();
  for (let index = state.rendered; index < end; index += 1) {
    fragment.append(createCard(state.filtered[index]));
  }
  elements.grid.append(fragment);
  state.rendered = end;
}

function buildField(container, meta, registry, key, extraClass) {
  const field = elements.fieldTemplate.content.firstElementChild.cloneNode(true);
  if (extraClass) field.classList.add(extraClass);
  const label = field.querySelector(".nutrient-label");
  label.append(document.createTextNode(meta.names.ru || meta.code));
  const code = document.createElement("code");
  code.textContent = meta.code;
  label.append(code);
  field.querySelector(".nutrient-unit").textContent = meta.unit_label;
  const input = field.querySelector("input");
  input.dataset.key = key;
  input.addEventListener("input", () => onFieldInput(input));
  registry[key] = input;
  container.append(field);
}

function buildFields(catalog) {
  for (const meta of catalog.macros) {
    buildField(elements.macroFields, meta, macroInputs, meta.json_key, "macro");
  }
  for (const meta of catalog.minerals) {
    buildField(elements.mineralFields, meta, microInputs, meta.code);
  }
  for (const meta of catalog.vitamins) {
    buildField(elements.vitaminFields, meta, microInputs, meta.code);
  }
}

function onFieldInput(input) {
  const wrap = input.closest(".nutrient-input");
  const parsed = parseAmount(input.value);
  input.classList.toggle("invalid", Boolean(parsed.invalid));
  wrap.classList.toggle("changed", input.value.trim() !== (input.dataset.initial ?? ""));
}

function formSnapshot() {
  const names = Object.fromEntries(Object.entries(elements.nameInputs).map(([key, input]) => [key, input.value.trim()]));
  const macros = Object.fromEntries(Object.entries(macroInputs).map(([key, input]) => [key, input.value.trim()]));
  const micros = Object.fromEntries(Object.entries(microInputs).map(([key, input]) => [key, input.value.trim()]));
  return JSON.stringify({ names, category: elements.categoryInput.value.trim(), hasImage: Boolean(state.imageFile), macros, micros });
}

function setEditorImage(src, alt) {
  if (src) {
    elements.editorImage.src = src;
    elements.editorImage.alt = alt;
    elements.editorImage.hidden = false;
    elements.editorImageEmpty.hidden = true;
  } else {
    elements.editorImage.removeAttribute("src");
    elements.editorImage.hidden = true;
    elements.editorImageEmpty.hidden = false;
  }
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",", 2)[1]);
    reader.onerror = () => reject(new Error("Не удалось прочитать изображение"));
    reader.readAsDataURL(file);
  });
}

function isDirty() {
  return state.current && formSnapshot() !== state.initialForm;
}

function fillInput(input, value) {
  const text = displayAmount(value);
  input.value = text;
  input.dataset.initial = text.trim();
  input.classList.remove("invalid");
  input.closest(".nutrient-input").classList.remove("changed");
}

async function openEditor(slug) {
  if (state.saveInProgress) return;
  try {
    const response = await fetch(`/api/foods/${encodeURIComponent(slug)}`);
    const food = await response.json();
    if (!response.ok) throw new Error(food.error || "Не удалось открыть продукт");
    state.current = food;
    state.imageFile = null;
    elements.imageInput.value = "";
    const title = food.names.ru || food.names.uz_latn || food.slug;
    elements.editorTitle.textContent = title;
    elements.editorSlug.textContent = `${food.slug} · #${food.index + 1} · ${food.filled}/${food.total} микро`;
    for (const [locale, input] of Object.entries(elements.nameInputs)) input.value = food.names[locale] || "";
    elements.categoryInput.value = food.category || "";
    setEditorImage(food.image_url, title);
    for (const [key, input] of Object.entries(macroInputs)) fillInput(input, food.macros?.[key]);
    for (const [code, input] of Object.entries(microInputs)) fillInput(input, food.micros?.[code]);
    elements.saveStatus.textContent = "Изменения сохраняются в JSON и SQLite";
    state.initialForm = formSnapshot();
    elements.dialog.showModal();
    elements.nameInputs.uz_latn.focus();
    elements.nameInputs.uz_latn.select();
  } catch (error) {
    showToast(error.message, "error", 6000);
  }
}

function requestCloseEditor() {
  if (state.saveInProgress) return;
  if (isDirty() && !window.confirm("Закрыть редактор без сохранения изменений?")) return;
  elements.dialog.close();
  state.current = null;
  state.imageFile = null;
}

function collectPayload() {
  const macros = {};
  const micros = {};
  let firstInvalid = null;
  for (const [key, input] of Object.entries(macroInputs)) {
    const parsed = parseAmount(input.value);
    if (parsed.invalid || parsed.empty) {
      input.classList.add("invalid");
      firstInvalid = firstInvalid || { input, macro: true };
      continue;
    }
    macros[key] = input.value.trim().replace(",", ".");
  }
  for (const [code, input] of Object.entries(microInputs)) {
    const parsed = parseAmount(input.value);
    if (parsed.invalid) {
      input.classList.add("invalid");
      firstInvalid = firstInvalid || { input, macro: false };
      continue;
    }
    micros[code] = parsed.empty ? "" : input.value.trim().replace(",", ".");
  }
  return { macros, micros, firstInvalid };
}

async function saveEditor(event) {
  event.preventDefault();
  if (!state.current || state.saveInProgress || !elements.form.reportValidity()) return;
  const { macros, micros, firstInvalid } = collectPayload();
  if (firstInvalid) {
    firstInvalid.input.focus();
    showToast(
      firstInvalid.macro
        ? "Макронутриенты обязательны и должны быть числом ≥ 0"
        : "Проверьте выделенные поля: значение должно быть числом ≥ 0",
      "error",
      6000,
    );
    return;
  }

  state.saveInProgress = true;
  elements.saveEditor.disabled = true;
  elements.clearEditor.disabled = true;
  elements.saveEditor.textContent = "Сохраняем…";
  elements.saveStatus.textContent = "Сохраняем JSON и пересобираем базу…";
  try {
    const payload = {
      names: Object.fromEntries(Object.entries(elements.nameInputs).map(([locale, input]) => [locale, input.value])),
      category: elements.categoryInput.value,
      macros,
      micros,
    };
    if (state.imageFile) {
      payload.image = { mime: state.imageFile.type, base64: await fileToBase64(state.imageFile) };
    }
    const response = await fetch(`/api/foods/${encodeURIComponent(state.current.slug)}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Не удалось сохранить продукт");

    const index = state.foods.findIndex((food) => food.slug === result.slug);
    if (index >= 0) state.foods[index] = { ...state.foods[index], ...result };
    elements.dialog.close();
    state.current = null;
    state.imageFile = null;
    applyFilters();
    if (result.warning) showToast(result.warning, "warning", 7000);
    else showToast("Сохранено. JSON и SQLite обновлены.");
  } catch (error) {
    elements.saveStatus.textContent = error.message;
    showToast(error.message, "error", 7000);
  } finally {
    state.saveInProgress = false;
    elements.saveEditor.disabled = false;
    elements.clearEditor.disabled = false;
    elements.saveEditor.textContent = "Сохранить";
  }
}

function clearMicros() {
  if (!state.current) return;
  for (const input of Object.values(microInputs)) {
    input.value = "";
    onFieldInput(input);
  }
  elements.mineralFields.querySelector("input")?.focus();
}

let toastTimer;
function showToast(message, kind = "success", duration = 3500) {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.className = `toast visible ${kind}`;
  toastTimer = setTimeout(() => { elements.toast.className = "toast"; }, duration);
}

async function bootstrap() {
  try {
    const [catalogResponse, foodsResponse] = await Promise.all([
      fetch("/api/catalog"),
      fetch("/api/foods"),
    ]);
    const catalogData = await catalogResponse.json();
    const foodsData = await foodsResponse.json();
    if (!catalogResponse.ok) throw new Error(catalogData.error || "Не удалось получить список нутриентов");
    if (!foodsResponse.ok) throw new Error(foodsData.error || "Не удалось открыть базу");

    buildFields(catalogData.catalog);
    state.total = catalogData.total;
    state.foods = foodsData.items;
    elements.loading.hidden = true;
    populateCategories();
    applyFilters();
  } catch (error) {
    elements.loading.innerHTML = "";
    const title = document.createElement("h2");
    title.textContent = "Не удалось открыть базу";
    const detail = document.createElement("p");
    detail.textContent = error.message;
    elements.loading.append(title, detail);
  }
}

const observer = new IntersectionObserver((entries) => {
  if (entries.some((entry) => entry.isIntersecting)) appendBatch();
}, { rootMargin: "800px" });
observer.observe(elements.sentinel);

let searchTimer;
elements.search.addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(applyFilters, 90);
});
elements.fillFilter.addEventListener("change", applyFilters);
elements.categoryFilter.addEventListener("change", applyFilters);
elements.scrollTop.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "smooth" }));
elements.closeEditor.addEventListener("click", requestCloseEditor);
elements.cancelEditor.addEventListener("click", requestCloseEditor);
elements.clearEditor.addEventListener("click", clearMicros);
elements.form.addEventListener("submit", saveEditor);
elements.dialog.addEventListener("cancel", (event) => { event.preventDefault(); requestCloseEditor(); });
elements.dialog.addEventListener("click", (event) => {
  if (event.target === elements.dialog) requestCloseEditor();
});
elements.imageInput.addEventListener("change", () => {
  const [file] = elements.imageInput.files;
  if (!file) return;
  if (!["image/webp", "image/jpeg", "image/png"].includes(file.type)) {
    showToast("Выберите WEBP, JPG или PNG", "error");
    elements.imageInput.value = "";
    return;
  }
  if (file.size > 10 * 1024 * 1024) {
    showToast("Изображение больше 10 МБ", "error");
    elements.imageInput.value = "";
    return;
  }
  state.imageFile = file;
  setEditorImage(URL.createObjectURL(file), file.name);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "/" && !elements.dialog.open && document.activeElement !== elements.search) {
    event.preventDefault();
    elements.search.focus();
  }
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter" && elements.dialog.open) {
    event.preventDefault();
    elements.form.requestSubmit();
  }
});

bootstrap();
