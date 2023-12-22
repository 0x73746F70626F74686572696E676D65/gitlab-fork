import waitForPromises from 'helpers/wait_for_promises';
import SegmentedControlButtonGroup from '~/vue_shared/components/segmented_control_button_group.vue';
import {
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
} from 'ee/security_orchestration/components/policy_editor/constants';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';

export const switchRuleMode = async (wrapper, mode, awaitPromise = true) => {
  await wrapper.findComponent(SegmentedControlButtonGroup).vm.$emit('input', mode);

  if (awaitPromise) {
    await waitForPromises();
  }
};

export const findYamlPreview = (wrapper) => wrapper.findByTestId('rule-editor-preview-content');
const findYamlEditor = (wrapper) => wrapper.findComponent(YamlEditor);

export const getYamlPreviewText = (wrapper) => findYamlPreview(wrapper).text();
export const normaliseYaml = (yaml) => yaml.replaceAll('\n', '');
export const verify = async ({ manifest, verifyRuleMode, wrapper }) => {
  verifyRuleMode();
  expect(normaliseYaml(getYamlPreviewText(wrapper))).toBe(normaliseYaml(manifest));
  await switchRuleMode(wrapper, EDITOR_MODE_YAML);
  expect(findYamlEditor(wrapper).props('value')).toBe(manifest);
  await switchRuleMode(wrapper, EDITOR_MODE_RULE, false);

  expect(normaliseYaml(getYamlPreviewText(wrapper))).toBe(normaliseYaml(manifest));
  verifyRuleMode();
};
