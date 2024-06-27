<script>
import { s__ } from '~/locale';
import { SETTINGS_HUMANIZED_STRINGS } from '../../policy_editor/scan_result/lib/settings';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Override the following project settings'),
  },
  props: {
    settings: {
      type: Object,
      required: true,
    },
  },
  computed: {
    settingsList() {
      return Object.keys(this.settings).reduce((acc, setting) => {
        if (this.settings[setting] && Boolean(SETTINGS_HUMANIZED_STRINGS[setting])) {
          return [...acc, SETTINGS_HUMANIZED_STRINGS[setting]];
        }
        return acc;
      }, []);
    },
  },
};
</script>

<template>
  <div v-if="Boolean(settingsList.length)" class="gl-mt-5">
    <h5>{{ $options.i18n.title }}</h5>
    <ul>
      <li v-for="setting in settingsList" :key="setting">
        {{ setting }}
      </li>
    </ul>
  </div>
</template>
