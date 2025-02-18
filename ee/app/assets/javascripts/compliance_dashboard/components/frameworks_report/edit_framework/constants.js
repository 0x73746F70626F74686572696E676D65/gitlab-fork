import { __, s__, n__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const maxNameLength = 255;
export const i18n = {
  basicInformation: s__('ComplianceFrameworks|Basic information'),
  basicInformationDetails: s__('ComplianceFrameworks|Name, description'),
  nameInputReserved: (name) =>
    sprintf(
      s__(
        'ComplianceFrameworks|"%{name}" is a reserved word and cannot be used as a compliance framework name.',
      ),
      { name },
    ),

  policies: s__('ComplianceFrameworks|Policy'),
  policiesLinkedCount: (count) =>
    n__(
      'ComplianceFrameworks|%{count} linked policy.',
      'ComplianceFrameworks|%{count} linked policies.',
      count,
    ),
  policiesTotalCount: (/* count */) =>
    s__('ComplianceFrameworks|Total policies in the group: %{count}'),
  policiesTableFields: {
    linked: s__('ComplianceFrameworks|Linked'),
    name: s__('ComplianceFrameworks|Policy name'),
    description: s__('ComplianceFrameworks|Summary'),
  },
  policiesLinkedTooltip: s__(
    `ComplianceFrameworks|To unlink this policy and framework, edit the policy's scope.`,
  ),
  policiesUnlinkedTooltip: s__(
    `ComplianceFrameworks|To link this policy and framework,  edit  the policy's scope.`,
  ),

  addFrameworkTitle: s__('ComplianceFrameworks|Create a compliance framework'),
  editFrameworkTitle: s__('ComplianceFrameworks|Edit a compliance framework'),

  submitButtonText: s__('ComplianceFrameworks|Add framework'),

  deleteButtonText: s__('ComplianceFrameworks|Delete framework'),
  deleteButtonDisabledTooltip: s__(
    `ComplianceFrameworks|Compliance frameworks that are linked to an active policy can't be deleted`,
  ),
  deleteModalTitle: s__('ComplianceFrameworks|Delete compliance framework %{framework}'),
  deleteModalMessage: s__(
    'ComplianceFrameworks|You are about to permanently delete the compliance framework %{framework} from all projects which currently have it applied, which may remove other functionality. This cannot be undone.',
  ),

  successMessageText: s__('ComplianceFrameworks|Compliance framework created'),
  titleInputLabel: s__('ComplianceFrameworks|Name'),
  titleInputInvalid: s__(
    'ComplianceFrameworks|Name is required, and must be less than 255 characters',
  ),
  descriptionInputLabel: s__('ComplianceFrameworks|Description'),
  descriptionInputInvalid: s__('ComplianceFrameworks|Description is required'),
  pipelineConfigurationInputLabel: s__(
    'ComplianceFrameworks|Compliance pipeline configuration (optional)',
  ),
  pipelineConfigurationInputDescription: s__(
    'ComplianceFrameworks|Required format: %{codeStart}path/file.y[a]ml@group-name/project-name%{codeEnd}. %{linkStart}See some examples%{linkEnd}.',
  ),
  pipelineConfigurationInputDisabledPopoverTitle: s__(
    'ComplianceFrameworks|Requires Ultimate subscription',
  ),
  pipelineConfigurationInputDisabledPopoverContent: s__(
    'ComplianceFrameworks|Set compliance pipeline configuration for projects that use this framework. %{linkStart}How do I create the configuration?%{linkEnd}',
  ),
  pipelineConfigurationInputDisabledPopoverLink: helpPagePath(
    'user/group/compliance_frameworks.html#compliance-pipelines',
  ),
  pipelineConfigurationInputInvalidFormat: s__('ComplianceFrameworks|Invalid format'),
  pipelineConfigurationInputUnknownFile: s__('ComplianceFrameworks|Configuration not found'),
  colorInputLabel: s__('ComplianceFrameworks|Background color'),

  editSaveBtnText: __('Save changes'),
  addSaveBtnText: s__('ComplianceFrameworks|Add framework'),
  fetchError: s__(
    'ComplianceFrameworks|Error fetching compliance frameworks data. Please refresh the page or try a different framework',
  ),

  setAsDefault: s__('ComplianceFrameworks|Set as default'),
  setAsDefaultDetails: s__(
    'ComplianceFrameworks|Default framework will be applied automatically to any new project created in the group or sub group.',
  ),
  setAsDefaultOnlyOne: s__('ComplianceFrameworks|There can be only one default framework.'),
  deprecationWarning: {
    title: s__('ComplianceReport|Compliance pipelines are deprecated'),
    message: s__(
      'ComplianceReport|Avoid creating new compliance pipelines and use pipeline execution policy actions instead. %{linkStart}Pipeline execution policy%{linkEnd} actions provide the ability to enforce CI/CD jobs, execute security scans, and better manage compliance.',
    ),
    details: s__(
      'ComplianceReport|For more information, see %{linkStart}how to migrate from compliance pipelines to pipeline execution policy actions%{linkEnd}.',
    ),
    dismiss: s__('ComplianceReport|Dismiss'),
    migratePipelineToPolicy: s__('ComplianceReport|Migrate pipeline to a policy'),
  },

  projects: s__('ComplianceFrameworks|Projects'),
  projectsTableFields: {
    name: s__('ComplianceFrameworks|Project name'),
    desc: s__('ComplianceFrameworks|Project description'),
  },
  projectsTotalCount: (/* count */) =>
    s__('ComplianceFrameworks|Total projects linked to framework: %{count}'),
};
