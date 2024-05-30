<script>
import { GlModal, GlTruncate } from '@gitlab/ui';
import { sprintf, __, s__ } from '~/locale';

export default {
  i18n: {
    confirmTitle: s__(
      "SecurityOrchestration|Overwrite the current CI/CD code with the new file's content?",
    ),
    uploadFileButtonText: s__('SecurityOrchestration|Load CI/CD code from file'),
    uploadFileSuccess: s__('SecurityOrchestration|%{fileName} loaded succeeded.'),
    uploadFileFailure: s__('SecurityOrchestration|%{fileName} loading failed. Please try again.'),
  },
  name: 'CodeBlockImport',
  components: {
    GlModal,
    GlTruncate,
  },
  props: {
    hasExistingCode: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      hasError: false,
      showConfirmModal: false,
      showStatus: false,
      uploadedFileText: '',
      uploadedFile: null,
    };
  },
  computed: {
    uploadStatusText() {
      return this.hasError
        ? sprintf(this.$options.i18n.uploadFileFailure, {
            fileName: this.uploadedFile?.name || __('File'),
          })
        : sprintf(this.$options.i18n.uploadFileSuccess, { fileName: this.uploadedFile.name });
    },
  },
  methods: {
    clearInput() {
      this.$refs.codeUploadFileInput.value = null;
    },
    handleFileProcessed(element) {
      this.uploadedFileText = element?.target?.result;
      if (this.hasExistingCode) {
        this.showConfirmModal = true;
      } else {
        this.handleConfirmUpload();
      }
    },
    handleFileUpload(e) {
      this.uploadedFile = e?.target?.files[0];
      if (this.uploadedFile) {
        const processedFile = new FileReader();
        processedFile.readAsText(this.uploadedFile);
        processedFile.onload = this.handleFileProcessed;
        processedFile.onloadend = this.clearInput;
        processedFile.onerror = this.showError;
      } else {
        this.showError();
      }
    },
    handleConfirmUpload() {
      this.$emit('changed', this.uploadedFileText);
      this.hasError = false;
      this.showConfirmModal = false;
      this.showStatus = true;
    },
    removeFile() {
      this.uploadedFileText = '';
      this.uploadedFile = null;
      this.showStatus = false;
      this.showConfirmModal = false;
    },
    showError() {
      this.hasError = true;
      this.showStatus = true;
    },
  },
  modalId: 'confirm-upload-modal',
  confirmOptions: { text: __('Load new file'), attributes: { variant: 'confirm' } },
  cancelOptions: { text: __('Cancel') },
};
</script>

<template>
  <div class="gl-display-flex">
    <label for="code-upload" class="btn btn-default btn-md gl-button gl-mb-0 gl-font-normal">
      {{ $options.i18n.uploadFileButtonText }}
    </label>
    <input
      id="code-upload"
      ref="codeUploadFileInput"
      type="file"
      accept=".yml"
      name="code-upload"
      hidden="true"
      @change="handleFileUpload"
    />
    <gl-truncate
      v-if="showStatus"
      class="gl-display-flex gl-align-items-center gl-ml-3 gl-mb-0 gl-max-w-62"
      :text="uploadStatusText"
      position="middle"
      with-tooltip
    />
    <gl-modal
      v-model="showConfirmModal"
      :modal-id="$options.modalId"
      size="sm"
      :title="$options.i18n.confirmTitle"
      :action-primary="$options.confirmOptions"
      :action-secondary="$options.cancelOptions"
      @primary="handleConfirmUpload"
      @secondary="removeFile"
    />
  </div>
</template>
