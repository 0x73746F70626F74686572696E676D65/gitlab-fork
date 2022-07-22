import { s__ } from '~/locale';

export const resourceLinksI18n = Object.freeze({
  headerText: s__('LinkedResources|Linked resources'),
  helpText: s__('LinkedResources|Read more about linked resources'),
  addButtonText: s__('LinkedResources|Add a resource link'),
  fetchingLinkedResourcesText: s__('LinkedResources|Fetching linked resources'),
});

export const resourceLinksFormI18n = Object.freeze({
  linkTextLabel: s__('LinkedResources|Text (Optional)'),
  linkValueLabel: s__('LinkedResources|Link'),
  submitButtonText: s__('LinkedResources|Add'),
  cancelButtonText: s__('LinkedResources|Cancel'),
});

export const resourceLinksListI18n = Object.freeze({
  linkRemoveText: s__('LinkedResources|Remove'),
});
