<script>
import { GlModal } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { getExpiringSamlSession } from '../saml_sessions';

export default {
  components: {
    GlModal,
  },
  props: {
    samlProviderId: {
      type: Number,
      required: true,
    },
    samlSessionsUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      modalId: uniqueId('reload-saml-modal-'),
      showModal: false,
    };
  },
  async created() {
    const session = await getExpiringSamlSession({
      samlProviderId: this.samlProviderId,
      url: this.samlSessionsUrl,
    });

    if (session) {
      setTimeout(() => {
        this.showModal = true;
      }, session.timeRemainingMs);
    }
  },
  methods: {
    reload() {
      refreshCurrentPage();
    },
  },
  reload: { text: __('Reload page') },
  cancel: { text: __('Cancel') },
};
</script>

<template>
  <gl-modal
    v-model="showModal"
    :modal-id="modalId"
    :title="s__('SAML|Your SAML session has expired')"
    :action-primary="$options.reload"
    :action-cancel="$options.cancel"
    aria-live="assertive"
    @primary="reload"
  >
    {{
      s__(
        'SAML|Your SAML session has expired. Please, reload the page and sign in again, if necessary.',
      )
    }}
  </gl-modal>
</template>
