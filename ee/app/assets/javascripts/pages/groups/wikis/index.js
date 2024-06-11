import Wikis from '~/pages/shared/wikis/wikis';
import { mountApplications } from '~/pages/shared/wikis/edit';
import { mountWikiSidebarEntries } from '~/pages/shared/wikis/show';
import { mountMoreActions } from '~/pages/shared/wikis/more_actions';

mountApplications();
mountWikiSidebarEntries();
mountMoreActions();

export default new Wikis();
