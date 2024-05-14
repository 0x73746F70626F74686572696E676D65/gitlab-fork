<script>
import AgentMapping from 'ee_component/workspaces/agent_mapping/components/agent_mapping.vue';

export default {
  components: {
    AgentMapping,
  },
};
</script>
<template>
  <section class="settings-section settings-section-no-bottom">
    <div class="settings-sticky-header">
      <div class="settings-sticky-header-inner">
        <h3 class="gl-heading-3 m-0">{{ s__('Workspaces|Group agents') }}</h3>
      </div>
    </div>
    <p class="gl-text-secondary">
      {{
        s__(
          'Workspaces|Agents connect workspaces to your Kubernetes cluster. To create a workspace with an allowed agent, group members must have at least the Developer role.',
        )
      }}
    </p>
    <agent-mapping />
  </section>
</template>
