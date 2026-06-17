const state = {
  foods: [],
  filtered: [],
  rendered: 0,
  batchSize: 60,
  current: null,
  imageFile: null,
  initialForm: "",
  saveInProgress: false,
};

const localeMeta = [
  ["uz_latn", "UZ", "uz"],
  ["uz_cyrl", "ЎЗ", "cyrl"],
  ["ru", "RU", "ru"],
  ["en", "EN", "en"],
];

const elements = {
  grid: document.querySelector("#food-grid"),
  loading: document.querySelector("#loading"),
  empty: document.querySelector("#empty"),
  sentinel: document.querySelector("#load-sentinel"),
  search: document.querySelector("#search-input"),
  issueFilter: document.querySelector("#issue-filter"),
  categoryFilter: document.querySelector("#category-filter"),
  visibleCount: document.querySelector("#visible-count"),
  totalLabel: document.querySelector("#total-label"),
  scrollTop: document.querySelector("#scroll-top"),
  cardTemplate: document.querySelector("#card-template"),
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
  deleteEditor: document.querySelector("#delete-editor"),
  saveEditor: document.querySelector("#save-editor"),
  saveStatus: document.querySelector("#save-status"),
  toast: document.querySelector("#toast"),
};

function normalized(value) {
  return String(value ?? "").toLocaleLowerCase().replace(/ё/g, "е").trim();
}

function possibleIssues(food) {
  const values = Object.values(food.names);
  const missing = values.some((value) => !value.trim());
  const placeholder = values.some((value) => /(^|\s)(todo|tbd|null|undefined|\?\?+)(\s|$)/i.test(value));
  const whitespace = values.some((value) => value !== value.trim() || /\s{2,}/.test(value));
  const punctuation = values.some((value) => /[!?.,;:]{3,}/.test(value));
  return { missing, any: missing || placeholder || whitespace || punctuation };
}

function searchableText(food) {
  return normalized([food.slug, food.category, ...Object.values(food.names)].join(" "));
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
  const issueMode = elements.issueFilter.value;
  const category = elements.categoryFilter.value;
  state.filtered = state.foods.filter((food) => {
    if (query && !searchableText(food).includes(query)) return false;
    if (category !== "all" && food.category !== category) return false;
    const issues = possibleIssues(food);
    if (issueMode === "issues" && !issues.any) return false;
    if (issueMode === "missing" && !issues.missing) return false;
    return true;
  });
  state.rendered = 0;
  elements.grid.replaceChildren();
  updateCount();
  elements.empty.hidden = state.filtered.length !== 0;
  appendBatch();
}

function buildNameRow(locale, label, className, value) {
  const row = document.createElement("div");
  row.className = "name-row";
  const badge = document.createElement("b");
  badge.className = `locale-badge ${className}`;
  badge.textContent = label;
  const text = document.createElement("span");
  text.className = `name-value${value ? "" : " missing"}`;
  text.textContent = value || "Нет перевода";
  row.append(badge, text);
  return row;
}

function createCard(food) {
  const card = elements.cardTemplate.content.firstElementChild.cloneNode(true);
  card.dataset.slug = food.slug;
  card.setAttribute("aria-label", `Редактировать ${food.names.ru || food.names.uz_latn || food.slug}`);

  const image = card.querySelector(".card-image");
  const imageEmpty = card.querySelector(".card-image-empty");
  if (food.image_url) {
    image.src = food.image_url;
    image.alt = food.names.ru || food.names.uz_latn || food.slug;
    imageEmpty.hidden = true;
  } else {
    image.hidden = true;
  }
  card.querySelector(".card-number").textContent = `#${food.index + 1}`;
  card.querySelector(".card-category").textContent = food.category || "Без категории";
  card.querySelector(".card-slug").textContent = food.slug;
  card.querySelector(".issue-pill").hidden = !possibleIssues(food).any;
  const list = card.querySelector(".name-list");
  for (const [locale, label, className] of localeMeta) {
    list.append(buildNameRow(locale, label, className, food.names[locale]));
  }
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

function formSnapshot() {
  return JSON.stringify({
    names: Object.fromEntries(Object.entries(elements.nameInputs).map(([key, input]) => [key, input.value])),
    category: elements.categoryInput.value,
    hasImage: Boolean(state.imageFile),
  });
}

function isDirty() {
  return state.current && formSnapshot() !== state.initialForm;
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

function openEditor(slug) {
  const food = state.foods.find((item) => item.slug === slug);
  if (!food) return;
  state.current = food;
  state.imageFile = null;
  elements.imageInput.value = "";
  elements.editorTitle.textContent = food.names.ru || food.names.uz_latn || food.slug;
  elements.editorSlug.textContent = `${food.slug} · #${food.index + 1}`;
  elements.categoryInput.value = food.category;
  for (const [locale, input] of Object.entries(elements.nameInputs)) input.value = food.names[locale];
  setEditorImage(food.image_url, food.names.ru || food.slug);
  elements.saveStatus.textContent = "Изменения сохраняются в JSON и SQLite";
  state.initialForm = formSnapshot();
  elements.dialog.showModal();
  elements.nameInputs.uz_latn.focus();
  elements.nameInputs.uz_latn.select();
}

function requestCloseEditor() {
  if (state.saveInProgress) return;
  if (isDirty() && !window.confirm("Закрыть редактор без сохранения изменений?")) return;
  elements.dialog.close();
  state.current = null;
  state.imageFile = null;
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",", 2)[1]);
    reader.onerror = () => reject(new Error("Не удалось прочитать изображение"));
    reader.readAsDataURL(file);
  });
}

async function saveEditor(event) {
  event.preventDefault();
  if (!state.current || state.saveInProgress || !elements.form.reportValidity()) return;
  state.saveInProgress = true;
  elements.saveEditor.disabled = true;
  elements.saveEditor.textContent = "Сохраняем…";
  elements.saveStatus.textContent = "Сохраняем JSON и пересобираем базу…";
  try {
    const payload = {
      names: Object.fromEntries(Object.entries(elements.nameInputs).map(([locale, input]) => [locale, input.value])),
      category: elements.categoryInput.value,
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
    elements.saveEditor.textContent = "Сохранить";
  }
}

async function deleteCurrentFood() {
  if (!state.current || state.saveInProgress) return;
  const food = state.current;
  const displayName = food.names.ru || food.names.uz_latn || food.slug;
  const confirmed = window.confirm(
    `Удалить «${displayName}» из базы?\n\nПродукт исчезнет из JSON и SQLite. ` +
    "Перед удалением будет создана резервная копия. Файл картинки останется на диске."
  );
  if (!confirmed) return;

  state.saveInProgress = true;
  elements.deleteEditor.disabled = true;
  elements.saveEditor.disabled = true;
  elements.deleteEditor.textContent = "Удаляем…";
  elements.saveStatus.textContent = "Удаляем продукт и пересобираем базу…";
  try {
    const response = await fetch(`/api/foods/${encodeURIComponent(food.slug)}`, { method: "DELETE" });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Не удалось удалить продукт");
    state.foods = state.foods.filter((item) => item.slug !== food.slug);
    elements.dialog.close();
    state.current = null;
    state.imageFile = null;
    applyFilters();
    if (result.warning) showToast(`Продукт удалён. ${result.warning}`, "warning", 7000);
    else showToast(`«${displayName}» удалён. Резервная копия сохранена.`);
  } catch (error) {
    elements.saveStatus.textContent = error.message;
    showToast(error.message, "error", 7000);
  } finally {
    state.saveInProgress = false;
    elements.deleteEditor.disabled = false;
    elements.saveEditor.disabled = false;
    elements.deleteEditor.textContent = "Удалить продукт";
  }
}

let toastTimer;
function showToast(message, kind = "success", duration = 3500) {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.className = `toast visible ${kind}`;
  toastTimer = setTimeout(() => { elements.toast.className = "toast"; }, duration);
}

async function loadFoods() {
  try {
    const response = await fetch("/api/foods");
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Не удалось открыть базу");
    state.foods = data.items;
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
elements.issueFilter.addEventListener("change", applyFilters);
elements.categoryFilter.addEventListener("change", applyFilters);
elements.scrollTop.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "smooth" }));
elements.closeEditor.addEventListener("click", requestCloseEditor);
elements.cancelEditor.addEventListener("click", requestCloseEditor);
elements.deleteEditor.addEventListener("click", deleteCurrentFood);
elements.form.addEventListener("submit", saveEditor);
elements.dialog.addEventListener("cancel", (event) => { event.preventDefault(); requestCloseEditor(); });
elements.dialog.addEventListener("click", (event) => {
  if (event.target === elements.dialog) requestCloseEditor();
});
elements.imageInput.addEventListener("change", () => {
  const [file] = elements.imageInput.files;
  if (!file) return;
  if (!['image/webp', 'image/jpeg', 'image/png'].includes(file.type)) {
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

loadFoods();
