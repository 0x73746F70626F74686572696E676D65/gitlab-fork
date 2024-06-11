<script>
import { GlButton, GlCard, GlTableLite, GlSprintf, GlLabel, GlPagination } from '@gitlab/ui';
import { updateHistory, getParameterByName, setUrlParams } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import getSecretsQuery from '../../graphql/queries/client/get_secrets.query.graphql';
import {
  NEW_ROUTE_NAME,
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  SCOPED_LABEL_COLOR,
  UNSCOPED_LABEL_COLOR,
  INITIAL_PAGE,
  PAGE_SIZE,
} from '../../constants';
import SecretActionsCell from './secret_actions_cell.vue';

export default {
  name: 'SecretsTable',
  components: {
    GlButton,
    GlCard,
    GlTableLite,
    GlSprintf,
    GlLabel,
    GlPagination,
    TimeAgo,
    UserDate,
    SecretActionsCell,
  },
  props: {
    isGroup: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      secrets: null,
      page: INITIAL_PAGE,
    };
  },
  apollo: {
    secrets: {
      query: getSecretsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        if (this.isGroup) {
          return data.group?.secrets;
        }
        return data.project?.secrets;
      },
    },
  },
  computed: {
    queryVariables() {
      return {
        fullPath: this.fullPath,
        isGroup: this.isGroup,
        offset: (this.page - 1) * PAGE_SIZE,
        limit: PAGE_SIZE,
      };
    },
    secretsCount() {
      return this.secrets?.count || 0;
    },
    secretsNodes() {
      return this.secrets?.nodes || [];
    },
    showPagination() {
      return this.secretsCount > PAGE_SIZE;
    },
  },
  created() {
    this.updateQueryParamsFromUrl();

    window.addEventListener('popstate', this.updateQueryParamsFromUrl);
  },
  destroyed() {
    window.removeEventListener('popstate', this.updateQueryParamsFromUrl);
  },
  methods: {
    getDetailsRoute: (id) => ({ name: DETAILS_ROUTE_NAME, params: { id } }),
    getEditRoute: (id) => ({ name: EDIT_ROUTE_NAME, params: { id } }),
    isScopedLabel(label) {
      return label.includes('::');
    },
    getLabelBackgroundColor(label) {
      return this.isScopedLabel(label) ? SCOPED_LABEL_COLOR : UNSCOPED_LABEL_COLOR;
    },
    updateQueryParamsFromUrl() {
      this.page = Number(getParameterByName('page')) || INITIAL_PAGE;
    },
    handlePageChange(page) {
      this.page = page;
      updateHistory({
        url: setUrlParams({ page }),
      });
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('Secrets|Name'),
    },
    {
      key: 'lastAccessed',
      label: s__('Secrets|Last accessed'),
    },
    {
      key: 'createdAt',
      label: s__('Secrets|Created'),
    },
    {
      key: 'actions',
      label: '',
      tdClass: 'gl-text-right gl-p-3!',
    },
  ],
  LONG_DATE_FORMAT_WITH_TZ,
  NEW_ROUTE_NAME,
  PAGE_SIZE,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-font-size-h-display">{{ s__('Secrets|Secrets') }}</h1>
    <p>
      <gl-sprintf
        :message="
          s__(
            'Secrets|Secrets represent sensitive information your CI job needs to complete work. This sensitive information can be items like API tokens, database credentials, or private keys. Unlike CI/CD variables, which are always presented to a job, secrets must be explicitly required by a job.',
          )
        "
      />
    </p>

    <gl-card
      class="gl-new-card"
      header-class="gl-new-card-header"
      body-class="gl-new-card-body gl-px-0"
    >
      <template #header>
        <div class="gl-new-card-title-wrapper">
          <h3 class="gl-new-card-title">
            {{ s__('Secrets|Stored secrets') }}
            <span class="gl-new-card-count" data-testid="secrets-count">{{ secretsCount }}</span>
          </h3>
        </div>
        <div class="gl-new-card-actions">
          <gl-button size="small" :to="$options.NEW_ROUTE_NAME" data-testid="new-secret-button">
            {{ s__('Secrets|New secret') }}
          </gl-button>
        </div>
      </template>
      <gl-table-lite :fields="$options.fields" :items="secretsNodes" stacked="md" class="gl-mb-0">
        <template #cell(name)="{ item: { id, name, labels } }">
          <router-link data-testid="secret-details-link" :to="getDetailsRoute(id)" class="gl-block">
            {{ name }}
          </router-link>
          <gl-label
            v-for="label in labels"
            :key="label"
            :title="label"
            :background-color="getLabelBackgroundColor(label)"
            :scoped="isScopedLabel(label)"
            class="gl-mt-3 gl-mr-3"
          />
        </template>
        <template #cell(lastAccessed)="{ item: { lastAccessed } }">
          <time-ago :time="lastAccessed" data-testid="secret-last-accessed" />
        </template>
        <template #cell(createdAt)="{ item: { createdAt } }">
          <user-date
            :date="createdAt"
            :date-format="$options.LONG_DATE_FORMAT_WITH_TZ"
            data-testid="secret-created-at"
          />
        </template>
        <template #cell(actions)="{ item: { id } }">
          <secret-actions-cell :details-route="getEditRoute(id)" />
        </template>
      </gl-table-lite>
    </gl-card>
    <gl-pagination
      v-if="showPagination"
      :value="page"
      :per-page="$options.PAGE_SIZE"
      :total-items="secretsCount"
      :prev-text="__('Prev')"
      :next-text="__('Next')"
      :label-next-page="__('Go to next page')"
      :label-prev-page="__('Go to previous page')"
      align="center"
      class="gl-mt-5"
      @input="handlePageChange"
    />
  </div>
</template>
