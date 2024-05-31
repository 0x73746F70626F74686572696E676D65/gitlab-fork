<script>
import { createAlert } from '~/alert';
import { sprintf, s__ } from '~/locale';
import {
  getGroupEnvironments,
  getProjectEnvironments,
  ENVIRONMENT_FETCH_ERROR,
  ENVIRONMENT_QUERY_LIMIT,
  mapEnvironmentNames,
} from '~/ci/common/private/ci_environments_dropdown';
import { ENTITY_PROJECT } from '../../constants';
import SecretForm from './secret_form.vue';

const i18n = {
  descriptionGroup: s__(
    'Secrets|Add a new secret to the group by following the instructions in the form below.',
  ),
  descriptionProject: s__(
    'Secrets|Add a new secret to the project by following the instructions in the form below.',
  ),
  titleNew: s__('Secrets|New secret'),
};

export default {
  name: 'SecretFormWrapper',
  components: {
    SecretForm,
  },
  props: {
    entity: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    secretId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      environments: [],
    };
  },
  apollo: {
    environments: {
      query() {
        return this.entity === ENTITY_PROJECT ? getProjectEnvironments : getGroupEnvironments;
      },
      variables() {
        return {
          first: ENVIRONMENT_QUERY_LIMIT,
          fullPath: this.fullPath,
          search: '',
        };
      },
      update(data) {
        if (this.entity === ENTITY_PROJECT) {
          return mapEnvironmentNames(data.project?.environments?.nodes || []);
        }

        return mapEnvironmentNames(data.group?.environmentScopes?.nodes || []);
      },
      error() {
        createAlert({ message: ENVIRONMENT_FETCH_ERROR });
      },
    },
  },
  computed: {
    areEnvironmentsLoading() {
      return this.$apollo.queries.environments.loading;
    },
    pageDescription() {
      if (this.entity === ENTITY_PROJECT) {
        return this.$options.i18n.descriptionProject;
      }

      return this.$options.i18n.descriptionGroup;
    },
    pageTitle() {
      if (this.isEditing) {
        // TODO: This will be changed to `secret.key` when we develop the Edit form
        // https://gitlab.com/gitlab-org/gitlab/-/issues/432384#note_1924027555
        return sprintf(s__('Secrets|Edit %{id}'), { id: this.secretId });
      }

      return this.$options.i18n.titleNew;
    },
  },
  methods: {
    searchEnvironment(searchTerm) {
      this.$apollo.queries.environments.refetch({ search: searchTerm });
    },
  },
  i18n,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-font-size-h-display">{{ pageTitle }}</h1>
    <p v-if="!isEditing">{{ pageDescription }}</p>
    <secret-form
      :are-environments-loading="areEnvironmentsLoading"
      :environments="environments"
      :full-path="fullPath"
      :is-editing="isEditing"
      @search-environment="searchEnvironment"
    />
  </div>
</template>
