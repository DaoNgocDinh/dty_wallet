var assert = require('assert');
var bcrypt = require('bcryptjs');
var User = require('../model/User');
var authController = require('../controller/authController');

var originalFindById = User.findById;
var currentPassword = 'Current123';

function mockResponse() {
  return {
    statusCode: 200,
    data: null,
    status: function(code) {
      this.statusCode = code;
      return this;
    },
    json: function(payload) {
      this.data = payload;
      return this;
    }
  };
}

async function createState() {
  var passwordHash = await bcrypt.hash(currentPassword, 4);
  var state = {
    persistedPassword: currentPassword,
    persistedPasswordHash: passwordHash,
    saveCalls: 0,
    shouldFailSave: false
  };
  state.user = {
    id: 'test-user',
    password: currentPassword,
    passwordHash: passwordHash,
    save: async function() {
      state.saveCalls++;
      if (state.shouldFailSave) throw new Error('Simulated storage failure');
      state.persistedPassword = this.password;
      state.persistedPasswordHash = this.passwordHash;
    }
  };
  return state;
}

async function invoke(body, state, res) {
  User.findById = function() {
    return { select: async function() { return state.user; } };
  };
  res = res || mockResponse();
  await authController.changePassword({
    body: body,
    user: { id: 'test-user' }
  }, res);
  return res;
}

async function runTests() {
  try {
    var invalidInputs = [
      [{ currentPassword: '', newPassword: 'Newpass123', confirmNewPassword: 'Newpass123' }, 'CURRENT_PASSWORD_REQUIRED'],
      [{ currentPassword: currentPassword, newPassword: '', confirmNewPassword: '' }, 'NEW_PASSWORD_REQUIRED'],
      [{ currentPassword: currentPassword, newPassword: 'Newpass123', confirmNewPassword: '' }, 'CONFIRM_PASSWORD_REQUIRED'],
      [{ currentPassword: currentPassword, newPassword: 'Abc1234', confirmNewPassword: 'Abc1234' }, 'INVALID_NEW_PASSWORD_LENGTH'],
      [{ currentPassword: currentPassword, newPassword: 'abcdefghijklmnopqrst1', confirmNewPassword: 'abcdefghijklmnopqrst1' }, 'INVALID_NEW_PASSWORD_LENGTH'],
      [{ currentPassword: currentPassword, newPassword: 'Onlyletters', confirmNewPassword: 'Onlyletters' }, 'NEW_PASSWORD_REQUIRES_LETTER_AND_NUMBER'],
      [{ currentPassword: currentPassword, newPassword: 'Newpass123', confirmNewPassword: 'Otherpass123' }, 'PASSWORD_CONFIRMATION_MISMATCH'],
      [{ currentPassword: 'Wrongpass123', newPassword: 'Newpass123', confirmNewPassword: 'Newpass123' }, 'INCORRECT_CURRENT_PASSWORD'],
      [{ currentPassword: currentPassword, newPassword: currentPassword, confirmNewPassword: currentPassword }, 'NEW_PASSWORD_SAME_AS_CURRENT']
    ];

    for (var testCase of invalidInputs) {
      var state = await createState();
      var res = await invoke(testCase[0], state);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.code, testCase[1]);
      assert.strictEqual(state.saveCalls, 0);
      assert.strictEqual(state.persistedPassword, currentPassword);
    }

    var successfulState = await createState();
    var success = await invoke({
      currentPassword: currentPassword,
      newPassword: 'Mậtkhẩu123',
      confirmNewPassword: 'Mậtkhẩu123'
    }, successfulState);
    assert.strictEqual(success.statusCode, 200);
    assert.strictEqual(success.data.message, 'Đổi mật khẩu thành công.');
    assert.strictEqual(successfulState.persistedPassword, 'Mậtkhẩu123');
    assert.strictEqual(
      await bcrypt.compare('Mậtkhẩu123', successfulState.persistedPasswordHash),
      true
    );

    var failedState = await createState();
    failedState.shouldFailSave = true;
    var originalError = console.error;
    console.error = function() {};
    try {
      var failure = await invoke({
        currentPassword: currentPassword,
        newPassword: 'Newpass123',
        confirmNewPassword: 'Newpass123'
      }, failedState);
      assert.strictEqual(failure.statusCode, 500);
      assert.strictEqual(failure.data.code, 'CHANGE_PASSWORD_FAILED');
      assert.strictEqual(
        failure.data.error,
        'Đổi mật khẩu thất bại. Vui lòng thử lại sau.'
      );
      assert.strictEqual(failedState.persistedPassword, currentPassword);
      assert.strictEqual(
        await bcrypt.compare(currentPassword, failedState.persistedPasswordHash),
        true
      );
    } finally {
      console.error = originalError;
    }

    console.log('[PASS] Đổi mật khẩu kiểm tra E1-E9, cập nhật thành công và lỗi lưu');
  } finally {
    User.findById = originalFindById;
  }
}

runTests().catch(function(error) {
  console.error(error);
  process.exitCode = 1;
});
