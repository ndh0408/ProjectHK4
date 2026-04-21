import React, {
    useCallback,
    useEffect,
    useMemo,
    useRef,
    useState,
} from 'react';
import {
    Alert,
    Avatar,
    Badge,
    Box,
    Chip,
    CircularProgress,
    Fade,
    IconButton,
    InputBase,
    List,
    ListItemAvatar,
    ListItemButton,
    ListItemText,
    Menu,
    MenuItem,
    Paper,
    Popover,
    Stack,
    Tooltip,
    Typography,
    alpha,
    useTheme,
} from '@mui/material';
import {
    Chat as ChatIcon,
    DoneAll as DoneAllIcon,
    Delete as DeleteIcon,
    Event as EventIcon,
    Groups as GroupsIcon,
    KeyboardArrowDown as ArrowDownIcon,
    MoreVert as MoreIcon,
    Refresh as RefreshIcon,
    Reply as ReplyIcon,
    Send as SendIcon,
    SentimentSatisfiedAlt as EmojiIcon,
    SignalWifi4Bar as OnlineIcon,
    SignalWifiOff as OfflineIcon,
    Close as CloseIcon,
} from '@mui/icons-material';
import { Client } from '@stomp/stompjs';
import { toast } from 'react-toastify';
import { format, isSameDay, isToday, isYesterday } from 'date-fns';

import chatApi from '../../api/chatApi';
import { useAuth } from '../../context/AuthContext';

const WS_URL = (() => {
    const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8080/api';
    try {
        const url = new URL(apiUrl);
        const protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
        return `${protocol}//${url.host}/ws/websocket`;
    } catch {
        return 'ws://localhost:8080/ws/websocket';
    }
})();

const EMOJIS = [
    '😀', '😃', '😄', '😁', '😆', '🥹', '😅', '🤣',
    '😂', '🙂', '🙃', '🫠', '😉', '😊', '😇', '🥰',
    '😍', '🤩', '😘', '😗', '😙', '😚', '😋', '😛',
    '🤔', '🫡', '🤐', '🤨', '😐', '😑', '😶', '🙄',
    '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
    '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
    '😰', '😥', '😓', '🤝', '🙏', '👍', '👎', '👏',
    '🙌', '🤲', '🫶', '❤️', '🧡', '💛', '💚', '💙',
    '💜', '🖤', '🤍', '💔', '🔥', '✨', '⭐', '🎉',
];

const formatTimestamp = (iso) => {
    if (!iso) return '';
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return '';
    return format(date, 'HH:mm');
};

const formatSidebarTime = (iso) => {
    if (!iso) return '';
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return '';
    if (isToday(date)) return format(date, 'HH:mm');
    if (isYesterday(date)) return 'Yesterday';
    const diffDays = (Date.now() - date.getTime()) / 86400000;
    if (diffDays < 7) return `${Math.floor(diffDays)}d`;
    return format(date, 'd MMM');
};

const formatDateSeparator = (iso) => {
    if (!iso) return '';
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return '';
    if (isToday(date)) return 'Today';
    if (isYesterday(date)) return 'Yesterday';
    return format(date, 'EEEE, d MMMM yyyy');
};

const previewFromMessage = (message) => {
    if (!message) return '';
    if (message.deleted) return 'Tin nhắn đã bị xoá';
    if (message.type === 'IMAGE') return '📷 Ảnh';
    if (message.type === 'FILE') return '📎 Tệp đính kèm';
    return message.content || '';
};

function useChatWebSocket({ token, onEvent }) {
    const [connected, setConnected] = useState(false);
    const clientRef = useRef(null);
    const desiredRef = useRef(new Set());
    const subsRef = useRef(new Map());
    const onEventRef = useRef(onEvent);

    useEffect(() => {
        onEventRef.current = onEvent;
    }, [onEvent]);

    useEffect(() => {
        if (!token) return undefined;

        const subs = subsRef.current;
        const desired = desiredRef.current;

        const client = new Client({
            brokerURL: WS_URL,
            connectHeaders: { Authorization: `Bearer ${token}` },
            reconnectDelay: 4000,
            debug: () => {},
        });

        const dispatch = (frame) => {
            try {
                const body = JSON.parse(frame.body);
                onEventRef.current?.(body);
            } catch {
                /* ignore */
            }
        };

        const subscribeConversation = (cid) => {
            const sub = client.subscribe(`/topic/conversation.${cid}`, dispatch);
            subs.set(cid, sub);
        };

        client.onConnect = () => {
            setConnected(true);
            // Server fans out new-message echoes to /user/queue/messages for
            // non-open conversations, so we subscribe once on connect.
            const userSub = client.subscribe('/user/queue/messages', dispatch);
            subs.set('__user_queue__', userSub);
            desired.forEach(subscribeConversation);
        };

        client.onStompError = () => setConnected(false);
        client.onWebSocketClose = () => {
            setConnected(false);
            subs.clear();
        };

        clientRef.current = client;
        client.activate();

        return () => {
            subs.clear();
            clientRef.current = null;
            client.deactivate();
            setConnected(false);
        };
    }, [token]);

    const subscribe = useCallback((cid) => {
        if (!cid) return;
        desiredRef.current.add(cid);
        const client = clientRef.current;
        if (!client || !client.connected) return;
        if (subsRef.current.has(cid)) return;
        const sub = client.subscribe(`/topic/conversation.${cid}`, (frame) => {
            try {
                onEventRef.current?.(JSON.parse(frame.body));
            } catch {
                /* ignore */
            }
        });
        subsRef.current.set(cid, sub);
    }, []);

    const unsubscribe = useCallback((cid) => {
        if (!cid) return;
        desiredRef.current.delete(cid);
        const existing = subsRef.current.get(cid);
        if (existing) {
            existing.unsubscribe();
            subsRef.current.delete(cid);
        }
    }, []);

    const publish = useCallback((destination, body = '') => {
        const client = clientRef.current;
        if (!client || !client.connected) return;
        client.publish({ destination, body });
    }, []);

    return { connected, subscribe, unsubscribe, publish };
}

// ---------------------- UI subcomponents ----------------------

const EmptyChat = () => (
    <Box
        sx={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexDirection: 'column',
            gap: 1.5,
            p: 4,
            background:
                'radial-gradient(circle at 50% 30%, rgba(99,102,241,0.06), transparent 60%)',
        }}
    >
        <Box
            sx={{
                width: 72,
                height: 72,
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: 'primary.50',
                color: 'primary.main',
            }}
        >
            <ChatIcon sx={{ fontSize: 36 }} />
        </Box>
        <Typography variant="h6" sx={{ fontWeight: 600 }}>
            Chọn một nhóm để bắt đầu
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 320, textAlign: 'center' }}>
            Tin nhắn mới sẽ xuất hiện tức thì qua WebSocket. Đồng bộ với ứng dụng
            mobile.
        </Typography>
    </Box>
);

const DateSeparator = ({ date }) => (
    <Box sx={{ display: 'flex', justifyContent: 'center', my: 1.5 }}>
        <Chip
            size="small"
            label={formatDateSeparator(date)}
            sx={{
                bgcolor: 'background.paper',
                border: '1px solid',
                borderColor: 'divider',
                fontSize: 11,
                fontWeight: 500,
                color: 'text.secondary',
                height: 22,
            }}
        />
    </Box>
);

const TypingDots = () => (
    <Box sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.3, ml: 0.5 }}>
        {[0, 1, 2].map((i) => (
            <Box
                key={i}
                sx={{
                    width: 4,
                    height: 4,
                    borderRadius: '50%',
                    bgcolor: 'primary.main',
                    animation: 'typingBlink 1.2s infinite',
                    animationDelay: `${i * 0.15}s`,
                    '@keyframes typingBlink': {
                        '0%, 60%, 100%': { opacity: 0.3 },
                        '30%': { opacity: 1 },
                    },
                }}
            />
        ))}
    </Box>
);

const MessageBubble = ({
    message,
    isMe,
    showAvatar,
    showName,
    onReply,
    onDelete,
}) => {
    const theme = useTheme();
    const [anchor, setAnchor] = useState(null);
    const openMenu = (e) => setAnchor(e.currentTarget);
    const closeMenu = () => setAnchor(null);

    return (
        <Stack
            direction="row"
            spacing={1}
            justifyContent={isMe ? 'flex-end' : 'flex-start'}
            alignItems="flex-end"
            sx={{ px: 1.5, '&:hover .msg-actions': { opacity: 1 } }}
        >
            {!isMe && (
                <Avatar
                    src={message.sender?.avatarUrl}
                    sx={{
                        width: 28,
                        height: 28,
                        visibility: showAvatar ? 'visible' : 'hidden',
                        border: '2px solid',
                        borderColor: 'background.paper',
                    }}
                >
                    {message.sender?.fullName?.charAt(0) || '?'}
                </Avatar>
            )}

            {isMe && (
                <Box
                    className="msg-actions"
                    sx={{
                        opacity: 0,
                        transition: 'opacity 0.15s',
                        display: 'flex',
                        alignItems: 'center',
                    }}
                >
                    <IconButton size="small" onClick={openMenu} sx={{ color: 'text.secondary' }}>
                        <MoreIcon fontSize="small" />
                    </IconButton>
                    <Menu anchorEl={anchor} open={!!anchor} onClose={closeMenu}>
                        <MenuItem
                            onClick={() => {
                                onReply?.(message);
                                closeMenu();
                            }}
                        >
                            <ReplyIcon fontSize="small" sx={{ mr: 1 }} />
                            Trả lời
                        </MenuItem>
                        {!message.deleted && (
                            <MenuItem
                                onClick={() => {
                                    onDelete?.(message);
                                    closeMenu();
                                }}
                                sx={{ color: 'error.main' }}
                            >
                                <DeleteIcon fontSize="small" sx={{ mr: 1 }} />
                                Xoá
                            </MenuItem>
                        )}
                    </Menu>
                </Box>
            )}

            <Box sx={{ maxWidth: '70%', minWidth: 80 }}>
                {!isMe && showName && (
                    <Typography
                        variant="caption"
                        color="text.secondary"
                        sx={{ ml: 1.5, fontWeight: 600, display: 'block' }}
                    >
                        {message.sender?.fullName || 'Unknown'}
                    </Typography>
                )}

                {message.replyTo && !message.deleted && (
                    <Box
                        sx={{
                            px: 1.25,
                            py: 0.75,
                            mb: 0.25,
                            ml: isMe ? 'auto' : 0,
                            maxWidth: '100%',
                            borderRadius: 1.5,
                            bgcolor: alpha(theme.palette.primary.main, 0.08),
                            borderLeft: `3px solid ${theme.palette.primary.main}`,
                            cursor: 'default',
                        }}
                    >
                        <Typography
                            variant="caption"
                            color="primary"
                            sx={{ fontWeight: 600, display: 'block' }}
                        >
                            {message.replyTo.senderName || '...'}
                        </Typography>
                        <Typography
                            variant="caption"
                            color="text.secondary"
                            sx={{
                                display: '-webkit-box',
                                WebkitLineClamp: 2,
                                WebkitBoxOrient: 'vertical',
                                overflow: 'hidden',
                            }}
                        >
                            {message.replyTo.content}
                        </Typography>
                    </Box>
                )}

                <Box
                    sx={{
                        px: 1.5,
                        py: 1,
                        borderRadius: 2.5,
                        borderTopLeftRadius: !isMe && showAvatar ? 0.5 : 2.5,
                        borderTopRightRadius: isMe ? 0.5 : 2.5,
                        background: isMe
                            ? `linear-gradient(135deg, ${theme.palette.primary.main}, ${theme.palette.primary.dark})`
                            : theme.palette.background.paper,
                        color: isMe ? 'primary.contrastText' : 'text.primary',
                        border: isMe ? 'none' : '1px solid',
                        borderColor: 'divider',
                        wordBreak: 'break-word',
                        boxShadow: isMe
                            ? `0 2px 8px ${alpha(theme.palette.primary.main, 0.25)}`
                            : '0 1px 2px rgba(0,0,0,0.04)',
                        display: 'inline-block',
                    }}
                >
                    {message.deleted ? (
                        <Typography
                            variant="body2"
                            sx={{ fontStyle: 'italic', opacity: 0.7 }}
                        >
                            Tin nhắn đã bị xoá
                        </Typography>
                    ) : message.type === 'IMAGE' && message.mediaUrl ? (
                        <Box
                            component="img"
                            src={message.mediaUrl}
                            alt=""
                            sx={{
                                maxWidth: 240,
                                maxHeight: 240,
                                borderRadius: 1.5,
                                display: 'block',
                            }}
                        />
                    ) : (
                        <Typography
                            variant="body2"
                            sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.4 }}
                        >
                            {message.content}
                        </Typography>
                    )}
                </Box>

                <Stack
                    direction="row"
                    spacing={0.5}
                    alignItems="center"
                    justifyContent={isMe ? 'flex-end' : 'flex-start'}
                    sx={{ mt: 0.25, mx: 1 }}
                >
                    <Typography variant="caption" color="text.secondary" sx={{ fontSize: 10 }}>
                        {formatTimestamp(message.createdAt)}
                    </Typography>
                    {isMe && !message.deleted && (
                        <DoneAllIcon
                            sx={{
                                fontSize: 12,
                                color: message.readByOthers
                                    ? 'primary.main'
                                    : 'text.disabled',
                            }}
                        />
                    )}
                </Stack>
            </Box>

            {!isMe && (
                <Box
                    className="msg-actions"
                    sx={{
                        opacity: 0,
                        transition: 'opacity 0.15s',
                    }}
                >
                    <Tooltip title="Trả lời">
                        <IconButton
                            size="small"
                            onClick={() => onReply?.(message)}
                            sx={{ color: 'text.secondary' }}
                        >
                            <ReplyIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                </Box>
            )}
        </Stack>
    );
};

const ReplyPreview = ({ replyingTo, onCancel }) => {
    if (!replyingTo) return null;
    return (
        <Box
            sx={{
                px: 2,
                py: 1,
                display: 'flex',
                alignItems: 'center',
                gap: 1,
                bgcolor: 'grey.50',
                borderLeft: '3px solid',
                borderColor: 'primary.main',
            }}
        >
            <ReplyIcon sx={{ fontSize: 18, color: 'primary.main' }} />
            <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="caption" color="primary" sx={{ fontWeight: 600, display: 'block' }}>
                    Trả lời {replyingTo.sender?.fullName || ''}
                </Typography>
                <Typography
                    variant="caption"
                    color="text.secondary"
                    noWrap
                    sx={{ display: 'block' }}
                >
                    {previewFromMessage(replyingTo)}
                </Typography>
            </Box>
            <IconButton size="small" onClick={onCancel}>
                <CloseIcon fontSize="small" />
            </IconButton>
        </Box>
    );
};

// ---------------------- Main page ----------------------

const EventChats = () => {
    const { user } = useAuth();
    const theme = useTheme();
    const token = useMemo(() => localStorage.getItem('accessToken'), []);

    const [chats, setChats] = useState([]);
    const [loadingChats, setLoadingChats] = useState(true);
    const [selectedId, setSelectedId] = useState(null);
    const [messages, setMessages] = useState([]);
    const [loadingMessages, setLoadingMessages] = useState(false);
    const [loadingMore, setLoadingMore] = useState(false);
    const [hasMore, setHasMore] = useState(false);
    const [currentPage, setCurrentPage] = useState(0);
    const [draft, setDraft] = useState('');
    const [sending, setSending] = useState(false);
    const [replyingTo, setReplyingTo] = useState(null);
    const [typingUsers, setTypingUsers] = useState({}); // { userId: {name, timeoutId} }
    const [emojiAnchor, setEmojiAnchor] = useState(null);
    const [showScrollDown, setShowScrollDown] = useState(false);

    const messagesScrollRef = useRef(null);
    const messagesEndRef = useRef(null);
    const appliedIdsRef = useRef(new Set());
    const selectedIdRef = useRef(null);
    const lastTypingSentRef = useRef(0);
    const atBottomRef = useRef(true);

    const selectedChat = chats.find((c) => c.conversationId === selectedId);

    useEffect(() => {
        selectedIdRef.current = selectedId;
    }, [selectedId]);

    const loadChats = useCallback(async () => {
        setLoadingChats(true);
        try {
            const list = await chatApi.listEventChats();
            setChats(list || []);
        } catch {
            toast.error('Không thể tải danh sách nhóm chat');
        } finally {
            setLoadingChats(false);
        }
    }, []);

    useEffect(() => {
        loadChats();
    }, [loadChats]);

    const loadMessages = useCallback(
        async (conversationId, { reset = true } = {}) => {
            if (!conversationId) return;
            if (reset) setLoadingMessages(true);
            else setLoadingMore(true);
            try {
                const pageToLoad = reset ? 0 : currentPage;
                const page = await chatApi.getMessages(conversationId, {
                    page: pageToLoad,
                    size: 30,
                });
                const pageMessages = [...(page.content || [])].reverse();

                if (reset) {
                    appliedIdsRef.current = new Set();
                    pageMessages.forEach((m) => appliedIdsRef.current.add(m.id));
                    setMessages(pageMessages);
                    setCurrentPage(1);
                } else {
                    pageMessages.forEach((m) => appliedIdsRef.current.add(m.id));
                    setMessages((prev) => [...pageMessages, ...prev]);
                    setCurrentPage((p) => p + 1);
                }
                setHasMore(!page.last);
                if (reset) {
                    await chatApi.markRead(conversationId);
                    setChats((prev) =>
                        prev.map((c) =>
                            c.conversationId === conversationId
                                ? { ...c, unreadCount: 0 }
                                : c,
                        ),
                    );
                }
            } catch {
                toast.error('Không thể tải tin nhắn');
            } finally {
                setLoadingMessages(false);
                setLoadingMore(false);
            }
        },
        [currentPage],
    );

    const handleEvent = useCallback(
        (event) => {
            if (!event) return;
            const { type, conversationId, message, userId, userName } = event;

            if (type === 'TYPING' && conversationId && userId && userId !== user?.id) {
                setTypingUsers((prev) => {
                    const existing = prev[userId];
                    if (existing?.timeoutId) clearTimeout(existing.timeoutId);
                    const timeoutId = setTimeout(() => {
                        setTypingUsers((p) => {
                            const { [userId]: _removed, ...rest } = p;
                            return rest;
                        });
                    }, 3500);
                    return {
                        ...prev,
                        [userId]: { name: userName, conversationId, timeoutId },
                    };
                });
                return;
            }

            if (type === 'MESSAGE_DELETED' && conversationId && message?.id) {
                setMessages((prev) =>
                    prev.map((m) =>
                        m.id === message.id
                            ? { ...m, deleted: true, content: 'Tin nhắn đã bị xoá' }
                            : m,
                    ),
                );
                return;
            }

            if (type !== 'NEW_MESSAGE') return;
            if (!message || !conversationId) return;

            if (appliedIdsRef.current.has(message.id)) return;
            appliedIdsRef.current.add(message.id);
            if (appliedIdsRef.current.size > 2000) {
                appliedIdsRef.current = new Set(
                    Array.from(appliedIdsRef.current).slice(-1000),
                );
            }

            const isOwnMessage = message.sender?.id === user?.id;
            const isOpenChat = conversationId === selectedIdRef.current;

            if (isOpenChat) {
                setMessages((prev) => {
                    if (prev.some((m) => m.id === message.id)) return prev;
                    return [...prev, message];
                });
            }

            setChats((prev) => {
                const idx = prev.findIndex((c) => c.conversationId === conversationId);
                if (idx < 0) return prev;
                const current = prev[idx];
                const shouldIncrement = !isOwnMessage && !isOpenChat;
                const updated = {
                    ...current,
                    lastMessageContent: previewFromMessage(message),
                    lastMessageAt: message.createdAt,
                    unreadCount: shouldIncrement
                        ? (current.unreadCount || 0) + 1
                        : current.unreadCount,
                };
                const next = [...prev];
                next.splice(idx, 1);
                next.unshift(updated);
                return next;
            });
        },
        [user?.id],
    );

    const { connected, subscribe, unsubscribe, publish } = useChatWebSocket({
        token,
        onEvent: handleEvent,
    });

    const handleSelect = useCallback(
        async (chat) => {
            if (chat.conversationId === selectedId) return;
            if (selectedId) unsubscribe(selectedId);
            setMessages([]);
            setReplyingTo(null);
            setHasMore(false);
            setCurrentPage(0);
            setTypingUsers({});
            appliedIdsRef.current = new Set();

            if (!chat.conversationId) {
                try {
                    const joined = await chatApi.joinEventChat(chat.eventId);
                    setChats((prev) =>
                        prev.map((c) => (c.eventId === chat.eventId ? joined : c)),
                    );
                    if (joined.conversationId) {
                        setSelectedId(joined.conversationId);
                        subscribe(joined.conversationId);
                        await loadMessages(joined.conversationId, { reset: true });
                    }
                } catch {
                    toast.error('Không thể tham gia nhóm chat');
                }
                return;
            }
            setSelectedId(chat.conversationId);
            subscribe(chat.conversationId);
            await loadMessages(chat.conversationId, { reset: true });
        },
        [selectedId, subscribe, unsubscribe, loadMessages],
    );

    const handleSend = useCallback(async () => {
        const text = draft.trim();
        if (!text || !selectedId || sending) return;
        setSending(true);
        const replyId = replyingTo?.id;
        try {
            const sent = await chatApi.sendMessage(selectedId, {
                content: text,
                replyToId: replyId,
            });
            setDraft('');
            setReplyingTo(null);
            appliedIdsRef.current.add(sent.id);
            setMessages((prev) => {
                if (prev.some((m) => m.id === sent.id)) return prev;
                return [...prev, sent];
            });
            setChats((prev) => {
                const idx = prev.findIndex((c) => c.conversationId === selectedId);
                if (idx < 0) return prev;
                const current = prev[idx];
                const updated = {
                    ...current,
                    lastMessageContent: previewFromMessage(sent),
                    lastMessageAt: sent.createdAt,
                };
                const next = [...prev];
                next.splice(idx, 1);
                next.unshift(updated);
                return next;
            });
        } catch (err) {
            const backendMsg = err?.response?.data?.message;
            toast.error(backendMsg || 'Không gửi được tin nhắn');
        } finally {
            setSending(false);
        }
    }, [draft, selectedId, sending, replyingTo]);

    const handleDelete = useCallback(async (message) => {
        try {
            await chatApi.deleteMessage(message.id);
            setMessages((prev) =>
                prev.map((m) =>
                    m.id === message.id
                        ? { ...m, deleted: true, content: 'Tin nhắn đã bị xoá' }
                        : m,
                ),
            );
        } catch {
            toast.error('Không xoá được tin');
        }
    }, []);

    const handleDraftChange = (value) => {
        setDraft(value);
        if (!selectedId) return;
        const now = Date.now();
        if (now - lastTypingSentRef.current > 2000) {
            lastTypingSentRef.current = now;
            publish(`/app/chat/${selectedId}/typing`);
        }
    };

    const handleEmojiPick = (emoji) => {
        setDraft((prev) => prev + emoji);
        setEmojiAnchor(null);
    };

    // Auto-scroll to bottom when new messages arrive if user is at bottom.
    useEffect(() => {
        const container = messagesScrollRef.current;
        if (!container) return;
        if (atBottomRef.current) {
            requestAnimationFrame(() => {
                messagesEndRef.current?.scrollIntoView({ block: 'end' });
            });
        }
    }, [messages]);

    const handleScroll = useCallback(
        (e) => {
            const el = e.currentTarget;
            const nearBottom =
                el.scrollHeight - el.scrollTop - el.clientHeight < 120;
            atBottomRef.current = nearBottom;
            setShowScrollDown(!nearBottom);

            if (el.scrollTop < 80 && hasMore && !loadingMore && !loadingMessages && selectedId) {
                const prevHeight = el.scrollHeight;
                loadMessages(selectedId, { reset: false }).then(() => {
                    // keep scroll position anchored to the first previously visible message
                    requestAnimationFrame(() => {
                        if (messagesScrollRef.current) {
                            messagesScrollRef.current.scrollTop =
                                messagesScrollRef.current.scrollHeight - prevHeight;
                        }
                    });
                });
            }
        },
        [hasMore, loadingMore, loadingMessages, selectedId, loadMessages],
    );

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
    };

    const totalUnread = chats.reduce((sum, c) => sum + (c.unreadCount || 0), 0);

    const currentTypingNames = Object.values(typingUsers)
        .filter((t) => t.conversationId === selectedId)
        .map((t) => t.name)
        .filter(Boolean);

    const renderedMessages = useMemo(() => {
        const out = [];
        let lastDate = null;
        for (let i = 0; i < messages.length; i += 1) {
            const m = messages[i];
            const msgDate = m.createdAt ? new Date(m.createdAt) : null;
            if (msgDate && (!lastDate || !isSameDay(lastDate, msgDate))) {
                out.push({ type: 'separator', key: `sep-${m.id}`, date: m.createdAt });
                lastDate = msgDate;
            }
            const prev = messages[i - 1];
            const next = messages[i + 1];
            const sameSenderAsPrev =
                prev && prev.sender?.id === m.sender?.id && !prev.deleted;
            const sameSenderAsNext =
                next && next.sender?.id === m.sender?.id;
            const isMe = m.sender?.id === user?.id;
            out.push({
                type: 'message',
                key: m.id,
                message: m,
                isMe,
                showAvatar: !isMe && !sameSenderAsNext,
                showName: !isMe && !sameSenderAsPrev,
            });
        }
        return out;
    }, [messages, user?.id]);

    return (
        <Box sx={{ height: 'calc(100vh - 140px)', display: 'flex', flexDirection: 'column' }}>
            <Stack
                direction="row"
                alignItems="center"
                justifyContent="space-between"
                sx={{ mb: 2 }}
            >
                <Box>
                    <Typography variant="h4" sx={{ fontWeight: 700, letterSpacing: '-0.01em' }}>
                        Event Group Chats
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Nhắn tin trong nhóm chat của các sự kiện bạn tổ chức hoặc tham gia · đồng bộ realtime với mobile.
                    </Typography>
                </Box>
                <Stack direction="row" spacing={1} alignItems="center">
                    <Chip
                        size="small"
                        icon={connected ? <OnlineIcon sx={{ fontSize: 14 }} /> : <OfflineIcon sx={{ fontSize: 14 }} />}
                        label={connected ? 'Realtime' : 'Disconnected'}
                        color={connected ? 'success' : 'default'}
                        variant="outlined"
                        sx={{ fontWeight: 500 }}
                    />
                    <Tooltip title="Refresh">
                        <IconButton onClick={loadChats} size="small">
                            <RefreshIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                    {totalUnread > 0 && (
                        <Badge color="error" badgeContent={totalUnread} max={99} />
                    )}
                </Stack>
            </Stack>

            <Paper
                elevation={0}
                sx={{
                    flex: 1,
                    display: 'flex',
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                    borderRadius: 3,
                    bgcolor: 'background.paper',
                }}
            >
                {/* Sidebar */}
                <Box
                    sx={{
                        width: 340,
                        borderRight: '1px solid',
                        borderColor: 'divider',
                        display: 'flex',
                        flexDirection: 'column',
                        bgcolor: 'background.paper',
                    }}
                >
                    <Stack
                        direction="row"
                        alignItems="center"
                        spacing={1}
                        sx={{
                            p: 2,
                            borderBottom: '1px solid',
                            borderColor: 'divider',
                            background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.08)}, transparent)`,
                        }}
                    >
                        <Box
                            sx={{
                                width: 32,
                                height: 32,
                                borderRadius: 1.5,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                bgcolor: 'primary.main',
                                color: 'primary.contrastText',
                            }}
                        >
                            <GroupsIcon sx={{ fontSize: 20 }} />
                        </Box>
                        <Box sx={{ flex: 1 }}>
                            <Typography variant="subtitle1" sx={{ fontWeight: 700, lineHeight: 1.1 }}>
                                Nhóm Sự Kiện
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {chats.length} nhóm
                            </Typography>
                        </Box>
                    </Stack>

                    <Box sx={{ flex: 1, overflowY: 'auto' }}>
                        {loadingChats ? (
                            <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                                <CircularProgress size={24} />
                            </Box>
                        ) : chats.length === 0 ? (
                            <Box sx={{ p: 4, textAlign: 'center' }}>
                                <EventIcon sx={{ fontSize: 44, color: 'text.disabled' }} />
                                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                    Chưa có nhóm chat sự kiện nào.
                                </Typography>
                            </Box>
                        ) : (
                            <List disablePadding>
                                {chats.map((chat) => {
                                    const isSelected = chat.conversationId === selectedId;
                                    const unread = chat.unreadCount || 0;
                                    return (
                                        <ListItemButton
                                            key={chat.eventId}
                                            selected={isSelected}
                                            onClick={() => handleSelect(chat)}
                                            sx={{
                                                alignItems: 'flex-start',
                                                py: 1.5,
                                                px: 2,
                                                borderBottom: '1px solid',
                                                borderColor: 'divider',
                                                gap: 1,
                                                '&.Mui-selected': {
                                                    bgcolor: alpha(theme.palette.primary.main, 0.08),
                                                    '&:hover': {
                                                        bgcolor: alpha(theme.palette.primary.main, 0.12),
                                                    },
                                                },
                                            }}
                                        >
                                            <ListItemAvatar sx={{ minWidth: 'auto' }}>
                                                <Badge
                                                    overlap="circular"
                                                    anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                                                    badgeContent={
                                                        chat.closed ? (
                                                            <Box
                                                                sx={{
                                                                    width: 12,
                                                                    height: 12,
                                                                    borderRadius: '50%',
                                                                    bgcolor: 'text.disabled',
                                                                    border: '2px solid',
                                                                    borderColor: 'background.paper',
                                                                }}
                                                            />
                                                        ) : null
                                                    }
                                                >
                                                    <Avatar
                                                        src={chat.eventImageUrl}
                                                        variant="rounded"
                                                        sx={{
                                                            bgcolor: 'primary.100',
                                                            color: 'primary.700',
                                                            width: 44,
                                                            height: 44,
                                                        }}
                                                    >
                                                        <EventIcon />
                                                    </Avatar>
                                                </Badge>
                                            </ListItemAvatar>
                                            <ListItemText
                                                sx={{ my: 0 }}
                                                primary={
                                                    <Stack
                                                        direction="row"
                                                        alignItems="center"
                                                        spacing={1}
                                                    >
                                                        <Typography
                                                            variant="body2"
                                                            sx={{
                                                                fontWeight: unread > 0 ? 700 : 600,
                                                                flex: 1,
                                                                overflow: 'hidden',
                                                                textOverflow: 'ellipsis',
                                                                whiteSpace: 'nowrap',
                                                            }}
                                                        >
                                                            {chat.eventTitle}
                                                        </Typography>
                                                        <Typography
                                                            variant="caption"
                                                            color={unread > 0 ? 'primary.main' : 'text.secondary'}
                                                            sx={{ fontWeight: unread > 0 ? 600 : 400 }}
                                                        >
                                                            {formatSidebarTime(chat.lastMessageAt)}
                                                        </Typography>
                                                    </Stack>
                                                }
                                                secondary={
                                                    <Stack
                                                        direction="row"
                                                        alignItems="center"
                                                        spacing={1}
                                                        sx={{ mt: 0.25 }}
                                                    >
                                                        <Typography
                                                            variant="caption"
                                                            color={unread > 0 ? 'text.primary' : 'text.secondary'}
                                                            sx={{
                                                                flex: 1,
                                                                overflow: 'hidden',
                                                                textOverflow: 'ellipsis',
                                                                whiteSpace: 'nowrap',
                                                                fontWeight: unread > 0 ? 600 : 400,
                                                            }}
                                                        >
                                                            {chat.lastMessageContent ||
                                                                (chat.joined
                                                                    ? 'Chưa có tin nhắn'
                                                                    : 'Nhấn để tham gia')}
                                                        </Typography>
                                                        {unread > 0 && (
                                                            <Box
                                                                sx={{
                                                                    minWidth: 20,
                                                                    height: 20,
                                                                    px: 0.75,
                                                                    borderRadius: '10px',
                                                                    bgcolor: 'primary.main',
                                                                    color: 'primary.contrastText',
                                                                    display: 'flex',
                                                                    alignItems: 'center',
                                                                    justifyContent: 'center',
                                                                    fontSize: 11,
                                                                    fontWeight: 700,
                                                                }}
                                                            >
                                                                {unread > 99 ? '99+' : unread}
                                                            </Box>
                                                        )}
                                                    </Stack>
                                                }
                                            />
                                        </ListItemButton>
                                    );
                                })}
                            </List>
                        )}
                    </Box>
                </Box>

                {/* Chat panel */}
                <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', bgcolor: alpha(theme.palette.primary.main, 0.02) }}>
                    {!selectedChat ? (
                        <EmptyChat />
                    ) : (
                        <>
                            <Stack
                                direction="row"
                                alignItems="center"
                                spacing={1.5}
                                sx={{
                                    px: 2.5,
                                    py: 1.5,
                                    borderBottom: '1px solid',
                                    borderColor: 'divider',
                                    bgcolor: 'background.paper',
                                }}
                            >
                                <Avatar
                                    src={selectedChat.eventImageUrl}
                                    variant="rounded"
                                    sx={{
                                        bgcolor: 'primary.100',
                                        color: 'primary.700',
                                        width: 40,
                                        height: 40,
                                    }}
                                >
                                    <EventIcon />
                                </Avatar>
                                <Box sx={{ flex: 1, minWidth: 0 }}>
                                    <Typography variant="subtitle1" sx={{ fontWeight: 700 }} noWrap>
                                        {selectedChat.eventTitle}
                                    </Typography>
                                    <Stack direction="row" alignItems="center" spacing={0.5}>
                                        <Typography variant="caption" color="text.secondary">
                                            {selectedChat.participantCount || 0} thành viên
                                        </Typography>
                                        {selectedChat.closed && (
                                            <>
                                                <Box sx={{ width: 2, height: 2, bgcolor: 'text.disabled', borderRadius: '50%' }} />
                                                <Typography variant="caption" color="error.main">
                                                    Đã đóng
                                                </Typography>
                                            </>
                                        )}
                                        {currentTypingNames.length > 0 && (
                                            <>
                                                <Box sx={{ width: 2, height: 2, bgcolor: 'text.disabled', borderRadius: '50%' }} />
                                                <Typography variant="caption" color="primary.main" sx={{ fontStyle: 'italic' }}>
                                                    {currentTypingNames.length === 1
                                                        ? `${currentTypingNames[0]} đang nhập`
                                                        : `${currentTypingNames.length} người đang nhập`}
                                                </Typography>
                                                <TypingDots />
                                            </>
                                        )}
                                    </Stack>
                                </Box>
                            </Stack>

                            <Box
                                ref={messagesScrollRef}
                                onScroll={handleScroll}
                                sx={{
                                    flex: 1,
                                    overflowY: 'auto',
                                    py: 2,
                                    position: 'relative',
                                }}
                            >
                                {loadingMore && (
                                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 1 }}>
                                        <CircularProgress size={18} />
                                    </Box>
                                )}
                                {loadingMessages ? (
                                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                                        <CircularProgress size={24} />
                                    </Box>
                                ) : messages.length === 0 ? (
                                    <Box sx={{ textAlign: 'center', py: 6 }}>
                                        <Typography variant="body2" color="text.secondary">
                                            Chưa có tin nhắn. Gửi tin đầu tiên nhé!
                                        </Typography>
                                    </Box>
                                ) : (
                                    <Stack spacing={0.25}>
                                        {renderedMessages.map((item) =>
                                            item.type === 'separator' ? (
                                                <DateSeparator key={item.key} date={item.date} />
                                            ) : (
                                                <MessageBubble
                                                    key={item.key}
                                                    message={item.message}
                                                    isMe={item.isMe}
                                                    showAvatar={item.showAvatar}
                                                    showName={item.showName}
                                                    onReply={setReplyingTo}
                                                    onDelete={handleDelete}
                                                />
                                            ),
                                        )}
                                        <div ref={messagesEndRef} />
                                    </Stack>
                                )}

                                <Fade in={showScrollDown}>
                                    <IconButton
                                        onClick={scrollToBottom}
                                        size="small"
                                        sx={{
                                            position: 'sticky',
                                            bottom: 8,
                                            left: '50%',
                                            ml: '-20px',
                                            bgcolor: 'background.paper',
                                            boxShadow: 2,
                                            border: '1px solid',
                                            borderColor: 'divider',
                                            '&:hover': { bgcolor: 'grey.100' },
                                            zIndex: 2,
                                        }}
                                    >
                                        <ArrowDownIcon fontSize="small" />
                                    </IconButton>
                                </Fade>
                            </Box>

                            {selectedChat.closed ? (
                                <Alert
                                    severity="info"
                                    icon={false}
                                    sx={{
                                        borderRadius: 0,
                                        borderTop: '1px solid',
                                        borderColor: 'divider',
                                    }}
                                >
                                    Nhóm chat đã đóng. Không thể gửi tin nhắn.
                                </Alert>
                            ) : (
                                <Box sx={{ bgcolor: 'background.paper', borderTop: '1px solid', borderColor: 'divider' }}>
                                    <ReplyPreview
                                        replyingTo={replyingTo}
                                        onCancel={() => setReplyingTo(null)}
                                    />
                                    <Stack
                                        direction="row"
                                        spacing={0.5}
                                        alignItems="flex-end"
                                        sx={{ px: 1.5, py: 1 }}
                                    >
                                        <Tooltip title="Emoji">
                                            <IconButton
                                                size="small"
                                                onClick={(e) => setEmojiAnchor(e.currentTarget)}
                                                sx={{ color: 'text.secondary' }}
                                            >
                                                <EmojiIcon />
                                            </IconButton>
                                        </Tooltip>
                                        <Popover
                                            open={!!emojiAnchor}
                                            anchorEl={emojiAnchor}
                                            onClose={() => setEmojiAnchor(null)}
                                            anchorOrigin={{ vertical: 'top', horizontal: 'left' }}
                                            transformOrigin={{ vertical: 'bottom', horizontal: 'left' }}
                                        >
                                            <Box
                                                sx={{
                                                    display: 'grid',
                                                    gridTemplateColumns: 'repeat(8, 32px)',
                                                    gap: 0.25,
                                                    p: 1,
                                                    maxWidth: 280,
                                                }}
                                            >
                                                {EMOJIS.map((emoji) => (
                                                    <IconButton
                                                        key={emoji}
                                                        size="small"
                                                        onClick={() => handleEmojiPick(emoji)}
                                                        sx={{
                                                            width: 32,
                                                            height: 32,
                                                            fontSize: 18,
                                                            p: 0,
                                                        }}
                                                    >
                                                        {emoji}
                                                    </IconButton>
                                                ))}
                                            </Box>
                                        </Popover>

                                        <InputBase
                                            value={draft}
                                            onChange={(e) => handleDraftChange(e.target.value)}
                                            onKeyDown={(e) => {
                                                if (e.key === 'Enter' && !e.shiftKey) {
                                                    e.preventDefault();
                                                    handleSend();
                                                }
                                            }}
                                            placeholder="Nhập tin nhắn... (Enter để gửi, Shift+Enter xuống dòng)"
                                            multiline
                                            maxRows={5}
                                            sx={{
                                                flex: 1,
                                                px: 1.75,
                                                py: 1,
                                                borderRadius: 3,
                                                bgcolor: 'grey.100',
                                                fontSize: 14,
                                                border: '1px solid',
                                                borderColor: 'transparent',
                                                transition: 'border-color 0.15s',
                                                '&:focus-within': {
                                                    borderColor: 'primary.main',
                                                    bgcolor: 'background.paper',
                                                },
                                            }}
                                        />
                                        <Tooltip title="Gửi">
                                            <span>
                                                <IconButton
                                                    onClick={handleSend}
                                                    disabled={!draft.trim() || sending}
                                                    sx={{
                                                        background: `linear-gradient(135deg, ${theme.palette.primary.main}, ${theme.palette.primary.dark})`,
                                                        color: 'primary.contrastText',
                                                        width: 40,
                                                        height: 40,
                                                        '&:hover': {
                                                            background: `linear-gradient(135deg, ${theme.palette.primary.dark}, ${theme.palette.primary.main})`,
                                                        },
                                                        '&:disabled': {
                                                            background: 'grey.300',
                                                            color: 'grey.500',
                                                        },
                                                    }}
                                                >
                                                    {sending ? (
                                                        <CircularProgress
                                                            size={18}
                                                            sx={{ color: 'primary.contrastText' }}
                                                        />
                                                    ) : (
                                                        <SendIcon fontSize="small" />
                                                    )}
                                                </IconButton>
                                            </span>
                                        </Tooltip>
                                    </Stack>
                                </Box>
                            )}
                        </>
                    )}
                </Box>
            </Paper>
        </Box>
    );
};

export default EventChats;
