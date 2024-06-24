<script>
import {
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlSprintf,
  GlLink,
  GlLoadingIcon,
  GlAlert,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, s__, __ } from '~/locale';
import { BASE_ROLES_INC_MINIMAL_ACCESS } from '~/access_level/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';
import createMemberRoleMutation from '../graphql/create_member_role.mutation.graphql';
import updateMemberRoleMutation from '../graphql/update_member_role.mutation.graphql';
import memberRoleQuery from '../graphql/member_role.query.graphql';
import PermissionsSelector from './permissions_selector.vue';

export default {
  i18n: {
    createError: s__('MemberRole|Failed to create role.'),
    createErrorWithReason: s__('MemberRole|Failed to create role: %{error}'),
    updateError: s__('MemberRole|Failed to save role.'),
    updateErrorWithReason: s__('MemberRole|Failed to save role: %{error}'),
    fetchRoleError: s__('MemberRole|Failed to load custom role.'),
    createRole: s__('MemberRole|Create role'),
    editRole: s__('MemberRole|Edit role'),
    saveRole: s__('MemberRole|Save role'),
    cancel: __('Cancel'),
    baseRoleLabel: s__('MemberRole|Base role'),
    baseRoleHelpText: s__(
      'MemberRole|Select a %{linkStart}pre-existing static role%{linkEnd} to predefine a set of permissions.',
    ),
    nameLabel: s__('MemberRole|Name'),
    descriptionLabel: s__('MemberRole|Description'),
    descriptionHelpText: s__(
      'MemberRole|Example: "Developer with admin and read access to vulnerability"',
    ),
    permissionsLabel: s__('MemberRole|Permissions'),
    invalidFeedback: __('This field is required.'),
    validationError: s__('MemberRole|You must fill out all required fields.'),
  },
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlSprintf,
    GlLink,
    GlLoadingIcon,
    GlAlert,
    PermissionsSelector,
  },
  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    listPagePath: {
      type: String,
      required: false,
      default: '',
    },
    roleId: {
      type: Number,
      required: false,
      default: null,
    },
    embedded: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      alert: null,
      memberRole: {
        name: '',
        description: '',
        baseAccessLevel: null,
        permissions: [],
      },
      isSubmitting: false,
      // If we're editing a role, mark the form as dirty so that validation is enabled immediately instead of after the
      // form is submitted for the first time.
      isDirty: this.roleId !== null,
    };
  },
  apollo: {
    memberRole: {
      query: memberRoleQuery,
      variables() {
        return { id: convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.roleId) };
      },
      update({ memberRole }) {
        return memberRole
          ? {
              ...memberRole,
              permissions: memberRole.enabledPermissions.nodes.map(({ value }) => value),
              baseAccessLevel: memberRole.baseAccessLevel.stringValue,
            }
          : null;
      },
      skip() {
        return !this.isEditing;
      },
      error() {
        this.memberRole = null;
      },
    },
  },
  computed: {
    isLoadingMemberRole() {
      return this.$apollo.queries.memberRole.loading;
    },
    isEditing() {
      return this.roleId !== null;
    },
    headerText() {
      return this.isEditing ? this.$options.i18n.editRole : this.$options.i18n.createRole;
    },
    saveButtonText() {
      return this.isEditing ? this.$options.i18n.saveRole : this.$options.i18n.createRole;
    },
    isNameValid() {
      return !this.isDirty || this.memberRole.name.length > 0;
    },
    isDescriptionValid() {
      return !this.isDirty || this.memberRole.description.length > 0;
    },
    isBaseRoleValid() {
      return !this.isDirty || this.memberRole.baseAccessLevel !== null;
    },
    isPermissionsValid() {
      return !this.isDirty || this.memberRole.permissions.length > 0;
    },
    staticRolesHelpPagePath() {
      return helpPagePath('user/permissions', { anchor: 'roles' });
    },
  },
  methods: {
    async saveMemberRole() {
      this.isDirty = true;
      this.alert?.dismiss();

      if (
        !this.isNameValid ||
        !this.isDescriptionValid ||
        !this.isBaseRoleValid ||
        !this.isPermissionsValid
      ) {
        this.alert = createAlert({ message: this.$options.i18n.validationError });
        return;
      }

      this.isSubmitting = true;

      try {
        const input = {
          name: this.memberRole.name,
          description: this.memberRole.description,
          permissions: this.memberRole.permissions,
        };

        if (this.isEditing) {
          input.id = convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.roleId);
        } else {
          input.baseAccessLevel = this.memberRole.baseAccessLevel;
          // Only add the groupPath key if we have one, otherwise backend may throw an error.
          if (this.groupFullPath) {
            input.groupPath = this.groupFullPath;
          }
        }

        const { data } = await this.$apollo.mutate({
          mutation: this.isEditing ? updateMemberRoleMutation : createMemberRoleMutation,
          variables: { input },
        });

        const error = data.memberRoleSave.errors[0];
        if (error) {
          this.isSubmitting = false;
          const errorMessage = this.isEditing
            ? this.$options.i18n.updateErrorWithReason
            : this.$options.i18n.createErrorWithReason;

          this.alert = createAlert({
            message: sprintf(errorMessage, { error }, false),
          });
        } else if (this.embedded) {
          this.$emit('success');
          this.isSubmitting = false;
        } else {
          visitUrl(this.listPagePath);
        }
      } catch {
        this.isSubmitting = false;
        this.alert = createAlert({
          message: sprintf(
            this.isEditing ? this.$options.i18n.updateError : this.$options.i18n.createError,
          ),
        });
      }
    },
    handleCancelClick() {
      if (this.embedded) {
        this.$emit('cancel');
      } else {
        visitUrl(this.listPagePath);
      }
    },
  },
  BASE_ROLES_INC_MINIMAL_ACCESS,
};
</script>

<template>
  <gl-loading-icon v-if="isLoadingMemberRole" size="lg" class="gl-mt-7" />

  <gl-alert v-else-if="!memberRole" :dismissible="false" variant="danger" class="gl-mt-5">
    {{ $options.i18n.fetchRoleError }}
  </gl-alert>

  <gl-form v-else @submit.prevent="saveMemberRole">
    <h4 v-if="embedded" class="gl-mt-0">{{ headerText }}</h4>
    <h2 v-else class="gl-mb-6">{{ headerText }}</h2>

    <gl-form-group
      :label="$options.i18n.nameLabel"
      label-for="role-name"
      :invalid-feedback="$options.i18n.invalidFeedback"
    >
      <gl-form-input
        id="role-name"
        v-model.trim="memberRole.name"
        :state="isNameValid"
        width="xl"
        maxlength="255"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionLabel"
      :invalid-feedback="$options.i18n.invalidFeedback"
      :description="$options.i18n.descriptionHelpText"
      label-for="description"
    >
      <gl-form-input
        id="description"
        v-model.trim="memberRole.description"
        :state="isDescriptionValid"
        width="xl"
        maxlength="255"
      />
    </gl-form-group>

    <h4 v-if="embedded" class="gl-mt-7">{{ $options.i18n.permissionsLabel }}</h4>
    <h3 v-else class="gl-mt-8 gl-mb-6">{{ $options.i18n.permissionsLabel }}</h3>

    <gl-form-group
      :label="$options.i18n.baseRoleLabel"
      :invalid-feedback="$options.i18n.invalidFeedback"
      label-for="base-role-select"
      label-class="gl-pb-1!"
      class="gl-mb-6"
    >
      <template #label-description>
        <div class="gl-mb-3">
          <gl-sprintf :message="$options.i18n.baseRoleHelpText">
            <template #link="{ content }">
              <gl-link :href="staticRolesHelpPagePath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </div>
      </template>
      <gl-form-select
        id="base-role-select"
        v-model="memberRole.baseAccessLevel"
        width="md"
        :disabled="isEditing"
        :options="$options.BASE_ROLES_INC_MINIMAL_ACCESS"
        :state="isBaseRoleValid"
      />
    </gl-form-group>

    <permissions-selector v-model="memberRole.permissions" :is-valid="isPermissionsValid" />

    <div class="gl-display-flex gl-flex-wrap gl-gap-3">
      <gl-button
        type="submit"
        :loading="isSubmitting"
        data-testid="submit-button"
        variant="confirm"
        class="js-no-auto-disable"
      >
        {{ saveButtonText }}
      </gl-button>
      <gl-button
        type="reset"
        data-testid="cancel-button"
        :disabled="isSubmitting"
        @click="handleCancelClick"
      >
        {{ $options.i18n.cancel }}
      </gl-button>
    </div>
  </gl-form>
</template>
