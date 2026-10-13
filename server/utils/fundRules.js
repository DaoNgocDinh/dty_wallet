var FundInvitation = require('../model/FundInvitation');

// Quỹ cặp đôi chỉ được có tối đa 2 người dùng (1 chủ quỹ + 1 người cùng lập quỹ).
var COUPLE_FUND_TYPE = 'Cặp đôi';
var COUPLE_FUND_MAX_MEMBERS = 2;

// Lấy danh sách id thành viên của quỹ (chủ quỹ luôn nằm trong members).
function getMemberIds(fund) {
  var ids = [];
  if (!fund) return ids;
  // userId / members.userId có thể đã được populate thành document người dùng
  if (fund.userId) ids.push((fund.userId._id || fund.userId).toString());
  if (Array.isArray(fund.members)) {
    fund.members.forEach(function(m) {
      var mid = m && m.userId ? (m.userId._id || m.userId).toString() : (m ? m.toString() : '');
      if (mid && ids.indexOf(mid) === -1) ids.push(mid);
    });
  }
  return ids;
}

function countMembers(fund) {
  return getMemberIds(fund).length;
}

function isCoupleFund(fund) {
  return !!fund && fund.fundType === COUPLE_FUND_TYPE;
}

function isFundOwner(fund, userId) {
  if (!fund || !userId) return false;
  var targetId = userId.toString();
  if (fund.userId) {
    // fund.userId có thể đã được populate thành document người dùng
    var ownerId = (fund.userId._id || fund.userId).toString();
    if (ownerId === targetId) return true;
  }
  if (Array.isArray(fund.members)) {
    return fund.members.some(function(m) {
      var mid = m && m.userId ? (m.userId._id || m.userId).toString() : (m ? m.toString() : '');
      return mid === targetId && m.role === 'owner';
    });
  }
  return false;
}

// Quỹ cặp đôi đã đủ 2 người dùng, hoặc đang chờ người được chọn đồng ý
// thì không được mời thêm bất kỳ ai nữa.
// Trả về null nếu quỹ vẫn còn chỗ, ngược lại trả về { status, body } để trả về cho client.
async function checkCoupleFundCapacity(fund) {
  if (!isCoupleFund(fund)) return null;

  if (countMembers(fund) >= COUPLE_FUND_MAX_MEMBERS) {
    return {
      status: 400,
      body: {
        error: 'Quỹ cặp đôi chỉ có 2 người dùng',
        code: 'COUPLE_FUND_FULL'
      }
    };
  }

  if (fund.status === 'pending_partner') {
    var pending = await FundInvitation.findOne({ fundId: fund._id, status: 'pending' });
    if (pending) {
      return {
        status: 400,
        body: {
          error: 'Quỹ cặp đôi đang chờ người được chọn đồng ý',
          code: 'COUPLE_FUND_PENDING'
        }
      };
    }
  }

  return null;
}

module.exports = {
  COUPLE_FUND_TYPE: COUPLE_FUND_TYPE,
  COUPLE_FUND_MAX_MEMBERS: COUPLE_FUND_MAX_MEMBERS,
  getMemberIds: getMemberIds,
  countMembers: countMembers,
  isCoupleFund: isCoupleFund,
  isFundOwner: isFundOwner,
  checkCoupleFundCapacity: checkCoupleFundCapacity
};