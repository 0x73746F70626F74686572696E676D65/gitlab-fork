<script>
import shieldCheckIllustrationUrl from '@gitlab/svgs/dist/illustrations/secure-sm.svg?url';
import magnifyingGlassIllustrationUrl from '@gitlab/svgs/dist/illustrations/search-sm.svg?url';
import pipelineIllustrationUrl from '@gitlab/svgs/dist/illustrations/milestone-sm.svg';
import { GlButton, GlCard, GlIcon, GlSprintf } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { s__, __, n__ } from '~/locale';
import { POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';

const i18n = {
  cancel: __('Cancel'),
  examples: __('Example'),
  selectPolicy: s__('SecurityOrchestration|Select policy'),
  scanResultPolicyTitle: s__('SecurityOrchestration|Merge request approval policy'),
  scanResultPolicyDesc: s__(
    'SecurityOrchestration|Use a merge request approval policy to create rules that check for security vulnerabilities and license compliance before merging a merge request.',
  ),
  scanResultPolicyExample: s__(
    'SecurityOrchestration|If any scanner finds a newly detected critical vulnerability in an open merge request targeting the main branch, then require two approvals from any two members of the application security team are required.',
  ),
  scanExecutionPolicyTitle: s__('SecurityOrchestration|Scan execution policy'),
  scanExecutionPolicyDesc: s__(
    'SecurityOrchestration|Use a scan execution policy to create rules which enforce security scans for particular branches at a certain time. Supported types are SAST, SAST IaC, DAST, Secret detection, Container scanning, and Dependency scanning.',
  ),
  scanExecutionPolicyExample: s__(
    'SecurityOrchestration|Run a DAST scan with Scan Profile A and Site Profile A when a pipeline run against the main branch.',
  ),
  maximumReachedWarning: s__(
    'SecurityOrchestration|You already have the maximum %{maximumAllowed} %{policyType} %{instance}.',
  ),
  pipelineExecutionPolicyTitle: s__('SecurityOrchestration|Pipeline execution policy'),
  pipelineExecutionPolicyDesc: s__(
    'SecurityOrchestration|Use a pipeline execution policy to enforce a custom CI/CD configuration to run in project pipelines.',
  ),
  pipelineExecutionPolicyExample: s__(
    'SecurityOrchestration|Run customized Gitlab security templates across my projects.',
  ),
};

export default {
  components: {
    GlButton,
    GlCard,
    GlIcon,
    GlSprintf,
  },
  directives: {
    SafeHtml,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'maxActiveScanExecutionPoliciesReached',
    'maxActiveScanResultPoliciesReached',
    'maxActivePipelineExecutionPoliciesReached',
    'maxScanExecutionPoliciesAllowed',
    'maxScanResultPoliciesAllowed',
    'maxPipelineExecutionPoliciesAllowed',
    'policiesPath',
  ],
  computed: {
    showPipelineExecutionPolicyType() {
      return this.glFeatures.pipelineExecutionPolicyType;
    },
    policies() {
      const policies = [
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.approval.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
          title: i18n.scanResultPolicyTitle,
          description: i18n.scanResultPolicyDesc,
          example: i18n.scanResultPolicyExample,
          imageSrc: shieldCheckIllustrationUrl,
          hasMax: this.maxActiveScanResultPoliciesReached,
          maxPoliciesAllowed: this.maxScanResultPoliciesAllowed,
        },
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          title: i18n.scanExecutionPolicyTitle,
          description: i18n.scanExecutionPolicyDesc,
          example: i18n.scanExecutionPolicyExample,
          imageSrc: magnifyingGlassIllustrationUrl,
          hasMax: this.maxActiveScanExecutionPoliciesReached,
          maxPoliciesAllowed: this.maxScanExecutionPoliciesAllowed,
        },
      ];

      if (this.showPipelineExecutionPolicyType) {
        policies.push({
          text: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          title: i18n.pipelineExecutionPolicyTitle,
          description: i18n.pipelineExecutionPolicyDesc,
          example: i18n.pipelineExecutionPolicyExample,
          imageSrc: pipelineIllustrationUrl,
          hasMax: this.maxActivePipelineExecutionPoliciesReached,
          maxPoliciesAllowed: this.maxPipelineExecutionPoliciesAllowed,
        });
      }

      return policies;
    },
  },
  methods: {
    instanceCountText(policyCount) {
      return n__('policy', 'policies', policyCount);
    },
  },
  i18n,
  safeHtmlConfig: { ADD_TAGS: ['use'] },
};
</script>
<template>
  <div class="gl-mb-4">
    <div
      class="gl-display-grid gl-md-grid-template-columns-2 gl-gap-6 gl-mb-4"
      data-testid="policy-selection-wizard"
    >
      <gl-card
        v-for="option in policies"
        :key="option.title"
        body-class="gl-p-6 gl-display-flex gl-flex-grow-1"
      >
        <div class="gl-mr-6 gl-text-white">
          <img :alt="option.title" aria-hidden="true" :src="option.imageSrc" />
        </div>
        <div class="gl-display-flex gl-flex-direction-column">
          <div>
            <h4 class="gl-display-inline-block gl-my-0">{{ option.title }}</h4>
          </div>
          <p class="gl-mt-5">{{ option.description }}</p>
          <h5>{{ $options.i18n.examples }}</h5>
          <p class="gl-flex-grow-1">{{ option.example }}</p>
          <div>
            <gl-button
              v-if="!option.hasMax"
              variant="confirm"
              :data-testid="`select-policy-${option.urlParameter}`"
              @click="$emit('select', option.urlParameter)"
            >
              {{ $options.i18n.selectPolicy }}
            </gl-button>
            <span
              v-else
              class="gl-text-orange-500"
              :data-testid="`max-allowed-text-${option.urlParameter}`"
            >
              <gl-icon name="warning" />
              <gl-sprintf :message="$options.i18n.maximumReachedWarning">
                <template #maximumAllowed>{{ option.maxPoliciesAllowed }}</template>
                <template #policyType>{{ option.text }}</template>
                <template #instance>{{ instanceCountText(option.maxPoliciesAllowed) }}</template>
              </gl-sprintf>
            </span>
          </div>
        </div>
      </gl-card>
    </div>
    <gl-button :href="policiesPath" data-testid="back-button">{{ $options.i18n.cancel }}</gl-button>
  </div>
</template>
