const http = require('http');

const buildId = '6a9b99488a6c99fa4b014f65';

async function check() {
  try {
    const res = await fetch("http://127.0.0.1:3000/api/codemagic/builds");
    const data = await res.json();
    const build = data.builds.find(b => b._id === buildId);
    if (!build) {
      console.log("Build not found!");
      process.exit(1);
    }
    
    if (build.status === 'finished') {
      console.log("Build finished successfully!");
      process.exit(0);
    } else if (build.status === 'failed' || build.status === 'canceled' || build.status === 'timeout') {
      console.log("Build failed with status:", build.status);
      process.exit(1);
    } else {
      setTimeout(check, 10000);
    }
  } catch (e) {
    console.error(e);
    setTimeout(check, 10000);
  }
}

check();
