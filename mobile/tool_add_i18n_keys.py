"""Batch-insert missing i18n keys into mobile l10n ARB files.

Reads app_en.arb + app_vi.arb, appends new keys listed below, writes them
back preserving the existing order and adding new keys at the end. Safe to
re-run (skips keys that already exist).
"""
import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).parent / "lib" / "l10n"
EN_FILE = ROOT / "app_en.arb"
VI_FILE = ROOT / "app_vi.arb"

# New keys: (en, vi, placeholders-dict-or-None)
NEW_KEYS = [
    # --- common actions / words ---
    ("close", "Close", "Đóng", None),
    ("edit", "Edit", "Sửa", None),
    ("block", "Block", "Chặn", None),
    ("unblock", "Unblock", "Bỏ chặn", None),
    ("connectAction", "Connect", "Kết nối", None),
    ("disconnectAction", "Disconnect", "Ngắt kết nối", None),
    ("transferAction", "Transfer", "Chuyển", None),
    ("addAction", "Add", "Thêm", None),
    ("decline", "Decline", "Từ chối", None),
    ("accept", "Accept", "Chấp nhận", None),
    ("yes", "Yes", "Có", None),
    ("no", "No", "Không", None),
    ("clearLabel", "Clear", "Xoá", None),
    ("all", "All", "Tất cả", None),
    ("tryAgain", "Try Again", "Thử lại", None),
    ("unknown", "Unknown", "Không rõ", None),
    ("errorLabel", "Error", "Lỗi", None),
    ("comingSoon", "Coming soon!", "Sắp ra mắt!", None),
    ("createAction", "Create", "Tạo", None),

    # --- Chat / conversation list ---
    ("messagesTitle", "Messages", "Tin nhắn", None),
    ("chatsTab", "Chats", "Trò chuyện", None),
    ("buddiesTab", "Buddies", "Bạn sự kiện", None),
    ("lumaTab", "LUMA", "LUMA", None),
    ("createGroupAction", "Create Group", "Tạo nhóm", None),
    ("createGroupChatTitle", "Create Group Chat", "Tạo nhóm chat", None),
    ("groupNameLabel", "Group Name", "Tên nhóm", None),
    ("groupNamePlaceholder", "Group name", "Tên nhóm", None),
    ("groupNameHint", "Enter group name...", "Nhập tên nhóm...", None),
    ("pleaseSelectMember", "Please select at least 1 member", "Vui lòng chọn ít nhất 1 thành viên", None),
    ("pleaseSelect2Buddies", "Please select at least 2 buddies to create a group", "Vui lòng chọn ít nhất 2 bạn để tạo nhóm", None),
    ("pleaseEnterGroupName", "Please enter a group name", "Vui lòng nhập tên nhóm", None),
    ("groupCreatedSnack", "Group created successfully!", "Đã tạo nhóm thành công!", None),
    ("groupCreatedNamed", "Group \"{name}\" created successfully!", "Đã tạo nhóm \"{name}\" thành công!", {"name": {"type": "String"}}),
    ("searchBuddiesHint", "Search buddies...", "Tìm bạn sự kiện...", None),
    ("exploreEventsAction", "Explore Events", "Khám phá sự kiện", None),
    ("clearFiltersAction", "Clear filters", "Xoá bộ lọc", None),
    ("clearAllAction", "Clear All", "Xoá tất cả", None),

    ("noMembersFound", "No members found", "Không tìm thấy thành viên", None),
    ("noMediaInChat", "No media in this chat", "Không có media trong nhóm này", None),
    ("viewProfile", "View Profile", "Xem hồ sơ", None),
    ("viewMembers", "View Members", "Xem thành viên",  None),
    ("searchInChat", "Search in Chat", "Tìm trong chat", None),
    ("mediaAndFiles", "Media & Files", "Media & Tệp", None),
    ("viewEventTooltip", "View Event", "Xem sự kiện", None),
    ("blockUserTitle", "Block User", "Chặn người dùng", None),
    ("blockUserConfirm", "Are you sure you want to block {name}? They will no longer be able to message you.", "Bạn có chắc muốn chặn {name}? Người này sẽ không thể nhắn tin cho bạn nữa.", {"name": {"type": "String"}}),
    ("userBlockedSnack", "{name} has been blocked", "Đã chặn {name}", {"name": {"type": "String"}}),
    ("failedToBlockUser", "Failed to block user: {error}", "Chặn người dùng thất bại: {error}", {"error": {"type": "String"}}),
    ("searchComingSoon", "Search coming soon", "Tìm kiếm sắp ra mắt", None),
    ("clearChatConfirm", "Are you sure you want to clear all messages? This action cannot be undone.", "Bạn có chắc muốn xoá tất cả tin nhắn? Không thể hoàn tác.", None),
    ("clearChatComingSoon", "Clear chat coming soon", "Xoá toàn bộ chat sắp ra mắt", None),

    ("deleteConversationTitle", "Delete conversation?", "Xoá cuộc trò chuyện?", None),
    ("deleteConversationMessage", "This will remove the conversation from your list. This action cannot be undone.", "Thao tác này sẽ xoá cuộc trò chuyện khỏi danh sách. Không thể hoàn tác.", None),
    ("failedToPinConversation", "Failed to pin conversation", "Ghim cuộc trò chuyện thất bại", None),
    ("failedToUnpinConversation", "Failed to unpin conversation", "Bỏ ghim cuộc trò chuyện thất bại", None),
    ("failedToArchiveConversation", "Failed to archive conversation", "Lưu trữ cuộc trò chuyện thất bại", None),
    ("failedToUnarchiveConversation", "Failed to unarchive conversation", "Bỏ lưu trữ thất bại", None),

    # --- chatbot ---
    ("lumaAssistantTitle", "LUMA Assistant", "Trợ lý LUMA", None),
    ("aiPoweredEventDiscovery", "AI-powered event discovery", "Khám phá sự kiện bằng AI", None),
    ("clearChatTooltip", "Clear chat", "Xoá lịch sử chat", None),
    ("errorWithDetails", "Error: {error}", "Lỗi: {error}", {"error": {"type": "String"}}),

    # --- networking / buddies ---
    ("networkingTitle", "Networking", "Kết nối", None),
    ("requestsTab", "Requests", "Yêu cầu", None),
    ("refreshTooltip", "Refresh", "Làm mới", None),
    ("noPendingRequests", "No pending requests", "Không có yêu cầu chờ", None),
    ("wantsToConnect", "Wants to connect", "Muốn kết nối", None),
    ("requestSentTo", "Request sent to {name}!", "Đã gửi yêu cầu đến {name}!", {"name": {"type": "String"}}),
    ("connectionAcceptedSnack", "Connection accepted!", "Đã chấp nhận kết nối!", None),
    ("eventBuddiesTitle", "Event Buddies", "Bạn sự kiện", None),
    ("discoverAndMatch", "Discover & Match", "Khám phá & Ghép đôi", None),

    # --- Calendar settings ---
    ("googleCalendarTitle", "Google Calendar", "Google Calendar", None),
    ("couldNotOpenGoogleAuth", "Could not open Google authorization page", "Không thể mở trang xác thực Google", None),
    ("googleCalendarConnected", "Google Calendar connected successfully!", "Đã kết nối Google Calendar!", None),
    ("googleCalendarDisconnected", "Google Calendar disconnected", "Đã ngắt kết nối Google Calendar", None),
    ("eventRemovedFromCalendar", "Event removed from Google Calendar", "Đã gỡ sự kiện khỏi Google Calendar", None),
    ("failedToConnect", "Failed to connect: {error}", "Kết nối thất bại: {error}", {"error": {"type": "String"}}),
    ("syncedEventsToCalendar", "Synced {count} events to Google Calendar", "Đã đồng bộ {count} sự kiện lên Google Calendar", {"count": {"type": "int"}}),
    ("enterAuthCodeTitle", "Enter Authorization Code", "Nhập mã xác thực", None),
    ("authorizationCodeLabel", "Authorization Code", "Mã xác thực", None),
    ("disconnectGoogleCalendar", "Disconnect Google Calendar", "Ngắt kết nối Google Calendar", None),
    ("syncAllAction", "Sync All", "Đồng bộ tất cả", None),

    # --- Profile ---
    ("profileUpdatedSnack", "Profile updated successfully", "Đã cập nhật hồ sơ", None),
    ("signatureRemovedSnack", "Signature removed", "Đã xoá chữ ký", None),
    ("removeSignatureConfirm", "Are you sure you want to remove your signature?", "Bạn có chắc muốn xoá chữ ký?", None),
    ("logoutTitle", "Logout", "Đăng xuất", None),
    ("logoutConfirmMessage", "Are you sure you want to logout?", "Bạn có chắc muốn đăng xuất?", None),
    ("photoUploadComingSoon", "Photo upload coming soon!", "Tải ảnh sắp ra mắt!", None),
    ("bioLabel", "Bio", "Giới thiệu", None),
    ("bioHint", "Tell others about yourself", "Nói về bản thân bạn", None),
    ("interestsLabel", "Interests", "Sở thích", None),
    ("interestsHint", "tech, music, travel (comma separated)", "tech, âm nhạc, du lịch (cách nhau bởi dấu phẩy)", None),
    ("networkingVisibility", "Networking Visibility", "Hiển thị trong Networking", None),
    ("allowOthersDiscover", "Allow others to discover and connect with you", "Cho phép người khác tìm thấy và kết nối với bạn", None),

    # --- Notifications / alerts ---
    ("markAllAsRead", "Mark all as read", "Đánh dấu tất cả đã đọc", None),
    ("waitlistOffersTooltip", "Waitlist Offers", "Ưu đãi danh sách chờ", None),
    ("imageUploadComingSoon", "Image upload coming soon!", "Tải ảnh sắp ra mắt!", None),
    ("failedToPickImage", "Failed to pick image: {error}", "Chọn ảnh thất bại: {error}", {"error": {"type": "String"}}),
    ("failedToSendMessage", "Failed to send message: {error}", "Gửi tin nhắn thất bại: {error}", {"error": {"type": "String"}}),
    ("replyFromUser", "Reply from {name}", "Trả lời từ {name}", {"name": {"type": "String"}}),
    ("typeYourAnswerHint", "Type your answer...", "Nhập câu trả lời...", None),
    ("chatDeletedSnack", "Chat deleted", "Đã xoá chat", None),
    ("deleteChatTitle", "Delete Chat", "Xoá chat", None),
    ("deleteChatConfirmLong", "Are you sure you want to delete this chat? This action cannot be undone.", "Bạn có chắc muốn xoá chat này? Không thể hoàn tác.", None),
    ("notificationsTitle", "Notifications", "Thông báo", None),

    # --- Waitlist offers ---
    ("waitlistOffersTitle", "Waitlist Offers", "Ưu đãi danh sách chờ", None),
    ("declineOfferTitle", "Decline Offer", "Từ chối ưu đãi", None),
    ("offerAcceptedSnack", "Offer accepted! You are now registered.", "Đã chấp nhận ưu đãi! Bạn đã được đăng ký.", None),
    ("offerDeclinedSnack", "Offer declined.", "Đã từ chối ưu đãi.", None),
    ("failedToAcceptOffer", "Failed to accept offer: {error}", "Chấp nhận ưu đãi thất bại: {error}", {"error": {"type": "String"}}),
    ("failedGeneric", "Failed: {error}", "Thất bại: {error}", {"error": {"type": "String"}}),

    # --- My events ---
    ("loginRequiredTitle", "Login Required", "Cần đăng nhập", None),
    ("loginRequiredMessage", "Please login to view your events", "Vui lòng đăng nhập để xem sự kiện của bạn", None),
    ("certificateSentSnack", "Certificate sent to your email!", "Đã gửi chứng chỉ tới email của bạn!", None),
    ("failedToSendCertificate", "Failed to send certificate: {error}", "Gửi chứng chỉ thất bại: {error}", {"error": {"type": "String"}}),
    ("registrationCancelledSnack", "Registration cancelled successfully", "Đã huỷ đăng ký", None),
    ("failedToCancelRegistration", "Failed to cancel: {error}", "Huỷ thất bại: {error}", {"error": {"type": "String"}}),
    ("cancelRegistrationTitle", "Cancel Registration", "Huỷ đăng ký", None),
    ("cancelRegistrationConfirm", "Are you sure you want to cancel this registration? This action cannot be undone.", "Bạn có chắc muốn huỷ đăng ký? Không thể hoàn tác.", None),
    ("yesCancel", "Yes, Cancel", "Có, huỷ", None),
    ("viewTicket", "View Ticket", "Xem vé", None),
    ("sendCertificateToEmail", "Send Certificate to Email", "Gửi chứng chỉ qua email", None),

    # --- Events / payment / ticket ---
    ("ticketLabel", "Ticket", "Vé", None),
    ("quantityLabel", "Quantity", "Số lượng", None),
    ("totalLabel", "Total", "Tổng", None),
    ("subtotalLabel", "Subtotal", "Tạm tính", None),
    ("unitPriceQtyLabel", "Unit price × Qty", "Đơn giá × Số lượng", None),
    ("haveCouponCode", "Have a coupon code?", "Có mã giảm giá?", None),
    ("enterCodeHint", "Enter code", "Nhập mã", None),
    ("registrationDeadlineLabel", "Registration Deadline", "Hạn đăng ký", None),
    ("livePollsLabel", "Live Polls", "Bình chọn trực tiếp", None),
    ("scheduleLabel", "Schedule", "Lịch trình", None),
    ("removedFromComparison", "Removed from comparison", "Đã bỏ khỏi so sánh", None),
    ("addedToComparison", "Added to comparison ({count}/4)", "Đã thêm vào so sánh ({count}/4)", {"count": {"type": "int"}}),
    ("maxEventsComparison", "Maximum 4 events for comparison", "Tối đa 4 sự kiện để so sánh", None),
    ("failedToValidateLabel", "Failed to validate: {error}", "Xác thực thất bại: {error}", {"error": {"type": "String"}}),

    ("transferTicketTitle", "Transfer Ticket", "Chuyển vé", None),
    ("transferInitiatedSnack", "Transfer initiated!", "Đã khởi tạo chuyển vé!", None),
    ("recipientEmailHint", "recipient@example.com", "nguoinhan@example.com", None),
    ("transferTicketTooltip", "Transfer ticket", "Chuyển vé", None),

    # --- Event schedule / polls ---
    ("registeredForSession", "Registered for session!", "Đã đăng ký phiên!", None),
    ("noSessionsAvailable", "No sessions available", "Chưa có phiên nào", None),
    ("addToMySchedule", "Add to My Schedule", "Thêm vào lịch của tôi", None),
    ("scheduleWithName", "Schedule - {name}", "Lịch trình - {name}", {"name": {"type": "String"}}),
    ("pollsWithName", "Polls — {name}", "Bình chọn — {name}", {"name": {"type": "String"}}),
    ("failedToSubmitPolls", "Failed to submit polls. Please try again.", "Gửi bình chọn thất bại. Vui lòng thử lại.", None),
    ("noEventsTitle", "No Events", "Chưa có sự kiện", None),

    # --- Explore / comparison ---
    ("eventComparisonTitle", "Event Comparison", "So sánh sự kiện", None),
    ("browseEventsAction", "Browse Events", "Xem sự kiện", None),
    ("noDataAvailable", "No data available", "Không có dữ liệu", None),
    ("noMoreEventsAvailable", "No more events available", "Không còn sự kiện", None),
    ("calendarSyncComingSoon", "Calendar sync coming soon!", "Đồng bộ lịch sắp ra mắt!", None),
    ("failedToLoadProfile", "Failed to load profile", "Tải hồ sơ thất bại", None),
    ("shareAction", "Share", "Chia sẻ", None),
    ("reportAction", "Report", "Báo cáo", None),
    ("reportSubmittedSnack", "Report submitted", "Đã gửi báo cáo", None),
    ("subscribedToCityUpdates", "Subscribed to city updates!", "Đã đăng ký nhận cập nhật thành phố!", None),
    ("noOrganisersAvailable", "No organisers available", "Không có nhà tổ chức", None),
    ("noCategoriesAvailable", "No categories available", "Không có danh mục", None),
    ("compareEventsTooltip", "Compare Events", "So sánh sự kiện", None),
    ("searchEventsHint", "Search events...", "Tìm sự kiện...", None),

    # --- Gallery ---
    ("galleryTitle", "Gallery", "Thư viện", None),
    ("failedToLoadCategories", "Failed to load categories", "Tải danh mục thất bại", None),
    ("viewEventLabel", "View Event", "Xem sự kiện", None),

    # --- Coupons ---
    ("couponCodeCopied", "Coupon code copied: {code}", "Đã sao chép mã: {code}", {"code": {"type": "String"}}),
    ("useThisCoupon", "Use this coupon", "Dùng mã này", None),

    # --- Shared widgets ---
    ("backOnlineSyncing", "Back online! Syncing data...", "Đã kết nối lại! Đang đồng bộ...", None),

    # --- Discover networking ---
    ("userLabel", "User", "Người dùng", None),
]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)


def save(path, data):
    text = json.dumps(data, ensure_ascii=False, indent=2)
    path.write_text(text + "\n", encoding="utf-8")


def add_key(arb, key, value, placeholders):
    if key in arb:
        return False
    arb[key] = value
    meta = {"description": key}
    if placeholders:
        meta["placeholders"] = placeholders
    arb[f"@{key}"] = meta
    return True


def main():
    en = load(EN_FILE)
    vi = load(VI_FILE)
    added_en = 0
    added_vi = 0
    for key, en_text, vi_text, placeholders in NEW_KEYS:
        if add_key(en, key, en_text, placeholders):
            added_en += 1
        if add_key(vi, key, vi_text, placeholders):
            added_vi += 1
    save(EN_FILE, en)
    save(VI_FILE, vi)
    print(f"Added EN: {added_en}, VI: {added_vi} (of {len(NEW_KEYS)} candidates)")


if __name__ == "__main__":
    main()
