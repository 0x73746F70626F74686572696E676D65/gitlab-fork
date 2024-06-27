import '~/pages/projects/settings/operations/show/index';
import mountStatusPageForm from 'ee/status_page_settings';
import mountObservabilitySettings from 'ee/observability_settings';
import initSettingsPanels from '~/settings_panels';

mountStatusPageForm();
mountObservabilitySettings();
initSettingsPanels();
