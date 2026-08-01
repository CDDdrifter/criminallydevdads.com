/** Entry: bootstrap auth paths, then mount React after Firebase redirect sign-in completes. */
import { bootstrapSpaAuthPaths } from './lib/authBootstrap';

bootstrapSpaAuthPaths();

void import('./main-app').then(({ mountApp }) => {
  void mountApp();
});
