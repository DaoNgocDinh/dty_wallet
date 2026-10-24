var path = require('path');
var spawnSync = require('child_process').spawnSync;

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

var tests = [
  'fund_test.js',
  'invite_member_test.js',
  'admin_test.js',
  'fund_withdraw_test.js',
  'couple_fund_test.js',
  'topup_test.js',
  'bill_payment_test.js',
  'feature_search_test.js',
  'spending_jar_test.js',
  'wallet_demo_deposit_test.js'
];

var selectedTests = process.argv.slice(2);
if (selectedTests.length) {
  var unknownTests = selectedTests.filter(function(test) {
    return tests.indexOf(test) === -1;
  });
  if (unknownTests.length) {
    console.error('Unknown test suite:', unknownTests.join(', '));
    process.exit(2);
  }
  tests = selectedTests;
}

var configuredUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/app_nhom11';
try {
  var testUri = new URL(configuredUri);
  var databasePath = testUri.pathname.replace(/\/+$/, '') || '/app_nhom11';
  testUri.pathname = databasePath + '_test';
  process.env.MONGODB_URI = testUri.toString();
} catch (error) {
  console.error('Cannot configure an isolated test database:', error.message);
  process.exit(2);
}

console.log('Running tests against an isolated MongoDB test database.');

for (var index = 0; index < tests.length; index++) {
  var result = spawnSync(
    process.execPath,
    [path.join(__dirname, tests[index])],
    { cwd: path.join(__dirname, '..'), env: process.env, stdio: 'inherit' }
  );
  if (result.error) {
    console.error('Could not start', tests[index] + ':', result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

console.log('All backend test suites passed.');
