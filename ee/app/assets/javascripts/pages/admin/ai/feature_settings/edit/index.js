const settingsEl = document.querySelectorAll('.js-self-hosted-model-setting');
const selfHostedModelSelect = document.querySelector('.js-self-hosted-model-select');

settingsEl.forEach((el) =>
  el.addEventListener('change', (event) => {
    const isSelfHosted = event.target.value === 'self_hosted';
    if (selfHostedModelSelect) {
      selfHostedModelSelect.disabled = !isSelfHosted;
    }
  }),
);
