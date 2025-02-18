import {
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/organizations/shared/utils';
import toast from '~/vue_shared/plugins/global_toast';
import { sprintf, __ } from '~/locale';

// Exports override for EE
// eslint-disable-next-line import/export
export * from '~/organizations/shared/utils';

// Exports override for EE
// eslint-disable-next-line import/export
export const renderDeleteSuccessToast = (item, type) => {
  // If delayed deletion is disabled or the project/group is already marked for deletion, use the CE toast
  if (!item.isAdjournedDeletionEnabled || item.markedForDeletionOn) {
    renderDeleteSuccessToastCE(item, type);
    return;
  }

  toast(
    sprintf(__("%{type} '%{name}' will be deleted on %{date}."), {
      type,
      name: item.name,
      date: item.permanentDeletionDate,
    }),
  );
};

// Exports override for EE
// eslint-disable-next-line import/export
export const deleteParams = (item) => {
  // If delayed deletion is disabled or the project/group is not yet marked for deletion, use the CE params
  if (!item.isAdjournedDeletionEnabled || !item.markedForDeletionOn) {
    return deleteParamsCE();
  }

  return { permanently_remove: true, full_path: item.fullPath };
};
