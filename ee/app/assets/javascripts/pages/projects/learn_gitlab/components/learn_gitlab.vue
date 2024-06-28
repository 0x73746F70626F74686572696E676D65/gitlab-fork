<script>
import { GlSprintf, GlAlert } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import eventHub from '~/invite_members/event_hub';
import { s__, n__ } from '~/locale';
import { getCookie, removeCookie, parseBoolean } from '~/lib/utils/common_utils';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import eventHubNav from '~/super_sidebar/event_hub';
import CircularProgressBar from 'ee/vue_shared/components/circular_progress_bar/circular_progress_bar.vue';
import { ACTION_LABELS, INVITE_MODAL_OPEN_COOKIE } from '../constants';
import LearnGitlabSectionCard from './learn_gitlab_section_card.vue';

export default {
  components: {
    GlSprintf,
    GlAlert,
    CircularProgressBar,
    LearnGitlabSectionCard,
  },
  i18n: {
    title: s__('LearnGitLab|Learn GitLab'),
    description: s__(
      'LearnGitLab|Ready to get started with GitLab? Follow these steps to set up your workspace, plan and commit changes, and deploy your project.',
    ),
    percentageCompleted: s__(`LearnGitLab|%{percentage}%{percentSymbol} completed`),
    successfulInvitations: s__(
      "LearnGitLab|Your team is growing! You've successfully invited new team members to the %{projectName} project.",
    ),
    addCodeBlockTitle: s__('LearnGitLab|1. Add code to your project'),
    buildBlockTitle: s__('LearnGitLab|2. Build'),
  },
  props: {
    actions: {
      required: true,
      type: Object,
    },
    sections: {
      required: true,
      type: Array,
    },
    project: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      showSuccessfulInvitationsAlert: false,
      actionsData: this.actions,
      isDesktop: bp.isDesktop(),
    };
  },
  computed: {
    firstBlockSections() {
      return Object.keys(this.sections[0]);
    },
    secondBlockSections() {
      return Object.keys(this.sections[1]);
    },
    maxValue() {
      return Object.keys(this.actionsData).length;
    },
    progressValue() {
      return Object.values(this.actionsData).filter((a) => a.completed).length;
    },
    progressPercentage() {
      return Math.round((this.progressValue / this.maxValue) * 100);
    },
    progressBarBlockClasses() {
      return {
        'gl-mt-6 gl-display-inline-block': true,
        'gl-ml-5': !this.isDesktop,
        'gl-h-0 gl-mr-5 gl-ml-auto': this.isDesktop,
      };
    },
    progressBarLabel() {
      const tasksToGo = this.maxValue - this.progressValue;

      if (tasksToGo > 0) {
        return n__('LearnGitLab|%d task to go', 'LearnGitLab|%d tasks to go', tasksToGo);
      }

      return s__('LearnGitLab|You completed all tasks!');
    },
  },
  mounted() {
    if (this.getCookieForInviteMembers()) {
      this.openInviteMembersModal('celebrate', ON_CELEBRATION_TRACK_LABEL);
    }

    eventHub.$on('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  beforeDestroy() {
    eventHub.$off('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  methods: {
    getCookieForInviteMembers() {
      const value = parseBoolean(getCookie(INVITE_MODAL_OPEN_COOKIE));

      removeCookie(INVITE_MODAL_OPEN_COOKIE);

      return value;
    },
    openInviteMembersModal(mode, source) {
      eventHub.$emit('openModal', { mode, source });
    },
    handleShowSuccessfulInvitationsAlert() {
      this.showSuccessfulInvitationsAlert = true;
      this.markActionAsCompleted('userAdded');
    },
    actionsFor(section) {
      const actions = Object.fromEntries(
        Object.entries(this.actionsData).filter(
          ([action]) => ACTION_LABELS[action].section === section,
        ),
      );
      return actions;
    },
    svgFor(index, section) {
      return this.sections[index][section].svg;
    },
    markActionAsCompleted(completedAction) {
      Object.keys(this.actionsData).forEach((action) => {
        if (action === completedAction) {
          this.actionsData[action].completed = true;
          this.modifySidebarPercentage();
        }
      });
    },
    modifySidebarPercentage() {
      eventHubNav.$emit('updatePillValue', {
        value: `${this.progressPercentage}%`,
        itemId: 'learn_gitlab',
      });
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showSuccessfulInvitationsAlert"
      variant="success"
      class="gl-mt-5"
      @dismiss="showSuccessfulInvitationsAlert = false"
    >
      <gl-sprintf :message="$options.i18n.successfulInvitations">
        <template #projectName>
          <strong>{{ project.name }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>
    <div class="row">
      <div class="col-sm-12 col-mb-9 col-lg-9">
        <h1 class="gl-font-size-h1">{{ $options.i18n.title }}</h1>
        <p class="gl-text-gray-700 gl-mb-0">{{ $options.i18n.description }}</p>
      </div>

      <div :class="progressBarBlockClasses" data-testid="progress-bar-block">
        <circular-progress-bar class="gl-mx-auto" :percentage="progressPercentage" />

        <div class="gl-mt-5 gl-text-center gl-font-lg gl-font-bold">
          {{ progressBarLabel }}
        </div>
      </div>
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-font-bold gl-font-size-h2">
        {{ $options.i18n.addCodeBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in firstBlockSections"
        :key="section"
        class="gl-mt-5 col-sm-12 col-mb-6 col-lg-4"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(0, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-font-bold gl-font-size-h2">
        {{ $options.i18n.buildBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in secondBlockSections"
        :key="section"
        class="gl-mt-5 col-sm-12 col-mb-6 col-lg-4"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(1, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>
  </div>
</template>
