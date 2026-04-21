import React, {
    useCallback,
    useDeferredValue,
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
    Search as SearchIcon,
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
import organiserApi from '../../api/organiserApi';
import { useAuth } from '../../context/AuthContext';
import { PageHeader } from '../../components/ui';
import { tokens } from '../../theme';

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
    if (message.deleted) return 'Message deleted';
    if (message.type === 'IMAGE') return '📷 Image';
    if (message.type === 'FILE') return '📎 Attachment';
    return message.content || '';
};

const normalizeSearchText = (value = '') =>
    value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .trim();

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
            gap: 2,
            p: 4,
            bgcolor: tokens.surfaces.page,
        }}
    >
        <Box
            sx={{
                width: 80,
                height: 80,
                borderRadius: tokens.radius.xl,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: tokens.gradient.primarySoft,
                boxShadow: tokens.shadow.md,
            }}
        >
            <ChatIcon sx={{ fontSize: 36, color: tokens.palette.primary[600] }} />
        </Box>
        <Typography variant="h6" sx={{ fontWeight: 700, color: tokens.text.strong, mt: 1 }}>
            Select a group to start
        </Typography>
        <Typography variant="body2" sx={{ maxWidth: 340, textAlign: 'center', color: tokens.text.secondary, lineHeight: 1.6 }}>
            New messages will appear instantly via WebSocket. Realtime sync with mobile app.
        </Typography>
    </Box>
);

const DateSeparator = ({ date }) => (
    <Box sx={{ display: 'flex', justifyContent: 'center', my: 2 }}>
        <Chip
            size="small"
            label={formatDateSeparator(date)}
            sx={{
                bgcolor: tokens.palette.neutral[100],
                border: `1px solid ${tokens.borders.subtle}`,
                fontSize: 11,
                fontWeight: 600,
                color: tokens.text.muted,
                height: 24,
                letterSpacing: '0.02em',
            }}
        />
    </Box>
);

const TypingDots = () => (
    <Box sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.4, ml: 0.5 }}>
        {[0, 1, 2].map((i) => (
            <Box
                key={i}
                sx={{
                    width: 5,
                    height: 5,
                    borderRadius: '50%',
                    bgcolor: tokens.palette.primary[500],
                    animation: 'typingBlink 1.2s infinite',
                    animationDelay: `${i * 0.18}s`,
                    '@keyframes typingBlink': {
                        '0%, 60%, 100%': { opacity: 0.25 },
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
    isOrganiser,
    showAvatar,
    showName,
    onReply,
    onDelete,
    onPin,
    onUnpin,
    onBan,
    onMute,
    isPinned = false,
}) => {
    const [anchor, setAnchor] = useState(null);
    const openMenu = (e) => setAnchor(e.currentTarget);
    const closeMenu = () => setAnchor(null);

    const isFromOrganiser = message.senderRole === 'ORGANISER';

    return (
        <Stack
            id={`msg-${message.id}`}
            direction="row"
            spacing={1}
            justifyContent={isMe ? 'flex-end' : 'flex-start'}
            alignItems="flex-end"
            sx={{
                px: { xs: 1.5, md: 2.5 },
                '&:hover .msg-actions': { opacity: 1 },
                position: 'relative',
            }}
        >
            {!isMe && (
                <Avatar
                    src={message.sender?.avatarUrl}
                    sx={{
                        width: 32,
                        height: 32,
                        visibility: showAvatar ? 'visible' : 'hidden',
                        fontSize: '0.8rem',
                        fontWeight: 600,
                        bgcolor: tokens.palette.primary[100],
                        color: tokens.palette.primary[700],
                        border: `2px solid ${tokens.surfaces.card}`,
                        boxShadow: tokens.shadow.sm,
                    }}
                >
                    {message.sender?.fullName?.charAt(0) || '?'}
                </Avatar>
            )}

            {(isMe || isOrganiser) && (
                <Box
                    className="msg-actions"
                    sx={{
                        opacity: 0,
                        transition: `opacity ${tokens.motion.fast}`,
                        display: 'flex',
                        alignItems: 'center',
                    }}
                >
                    <IconButton size="small" onClick={openMenu} sx={{ color: tokens.text.muted }}>
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
                            Reply
                        </MenuItem>

                        {isOrganiser && (
                            <>
                                <MenuItem
                                    onClick={() => {
                                        isPinned ? onUnpin?.(message) : onPin?.(message);
                                        closeMenu();
                                    }}
                                >
                                    <ReplyIcon fontSize="small" sx={{ mr: 1, transform: 'rotate(90deg)' }} />
                                    {isPinned ? 'Unpin' : 'Pin Message'}
                                </MenuItem>
                                {!isMe && (
                                    <>
                                        <MenuItem
                                            onClick={() => {
                                                onMute?.(message.sender?.id);
                                                closeMenu();
                                            }}
                                        >
                                            Mute
                                        </MenuItem>
                                        <MenuItem
                                            onClick={() => {
                                                onBan?.(message.sender?.id);
                                                closeMenu();
                                            }}
                                            sx={{ color: tokens.palette.danger[600] }}
                                        >
                                            Ban from event
                                        </MenuItem>
                                    </>
                                )}
                            </>
                        )}

                        {(!message.deleted && (isMe || isOrganiser)) && (
                            <MenuItem
                                onClick={() => {
                                    onDelete?.(message);
                                    closeMenu();
                                }}
                                sx={{ color: tokens.palette.danger[600] }}
                            >
                                <DeleteIcon fontSize="small" sx={{ mr: 1 }} />
                                Delete
                            </MenuItem>
                        )}
                    </Menu>
                </Box>
            )}

            <Box sx={{ maxWidth: { xs: '82%', lg: '65%' }, minWidth: 96 }}>
                {!isMe && showName && (
                    <Stack direction="row" alignItems="center" spacing={1} sx={{ ml: 1.5, mb: 0.5 }}>
                        <Typography
                            variant="caption"
                            sx={{
                                fontWeight: 700,
                                color: tokens.palette.primary[700],
                                fontSize: '0.7rem',
                                letterSpacing: '0.01em',
                            }}
                        >
                            {message.sender?.fullName || 'Unknown'}
                        </Typography>
                        {isFromOrganiser && (
                            <Chip
                                label="HOST"
                                size="small"
                                sx={{
                                    height: 16,
                                    fontSize: '0.6rem',
                                    fontWeight: 800,
                                    bgcolor: tokens.palette.primary[50],
                                    color: tokens.palette.primary[600],
                                    border: `1px solid ${tokens.palette.primary[100]}`,
                                    '& .MuiChip-label': { px: 0.5 },
                                }}
                            />
                        )}
                    </Stack>
                )}

                {message.replyTo && !message.deleted && (
                    <Box
                        sx={{
                            px: 1.5,
                            py: 0.75,
                            mb: 0.5,
                            ml: isMe ? 'auto' : 0,
                            maxWidth: '100%',
                            borderRadius: tokens.radius.sm,
                            bgcolor: tokens.palette.primary[50],
                            borderLeft: `3px solid ${tokens.palette.primary[400]}`,
                            cursor: 'default',
                        }}
                    >
                        <Typography
                            variant="caption"
                            sx={{ fontWeight: 700, display: 'block', color: tokens.palette.primary[700] }}
                        >
                            {message.replyTo.senderName || '...'}
                        </Typography>
                        <Typography
                            variant="caption"
                            sx={{
                                display: '-webkit-box',
                                WebkitLineClamp: 2,
                                WebkitBoxOrient: 'vertical',
                                overflow: 'hidden',
                                color: tokens.text.secondary,
                            }}
                        >
                            {message.replyTo.content}
                        </Typography>
                    </Box>
                )}

                <Box
                    sx={{
                        px: 1.75,
                        py: 1.25,
                        borderRadius: `${tokens.radius.lg}px`,
                        borderTopLeftRadius: !isMe && showAvatar ? tokens.radius.xs : tokens.radius.lg,
                        borderTopRightRadius: isMe ? tokens.radius.xs : tokens.radius.lg,
                        background: isMe
                            ? tokens.gradient.primary
                            : tokens.surfaces.card,
                        color: isMe ? '#fff' : tokens.text.primary,
                        border: isMe ? 'none' : `1px solid ${tokens.borders.subtle}`,
                        wordBreak: 'break-word',
                        boxShadow: isMe
                            ? tokens.shadow.primaryGlow
                            : tokens.shadow.xs,
                        display: 'inline-block',
                        transition: `box-shadow ${tokens.motion.fast}`,
                    }}
                >
                    {message.deleted ? (
                        <Typography
                            variant="body2"
                            sx={{ fontStyle: 'italic', opacity: 0.65 }}
                        >
                            {message.deletedByName 
                                ? `Message deleted by ${message.deletedByName}`
                                : 'This message was deleted'}
                        </Typography>
                    ) : message.type === 'IMAGE' && message.mediaUrl ? (
                        <Box
                            component="img"
                            src={message.mediaUrl}
                            alt=""
                            sx={{
                                maxWidth: 260,
                                maxHeight: 260,
                                borderRadius: tokens.radius.md,
                                display: 'block',
                            }}
                        />
                    ) : (
                        <Typography
                            variant="body2"
                            sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.5 }}
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
                    sx={{ mt: 0.5, mx: 1.25 }}
                >
                    <Typography variant="caption" sx={{ fontSize: 10, color: tokens.text.muted }}>
                        {formatTimestamp(message.createdAt)}
                    </Typography>
                    {isMe && !message.deleted && (
                        <DoneAllIcon
                            sx={{
                                fontSize: 13,
                                color: message.readByOthers
                                    ? tokens.palette.primary[500]
                                    : tokens.text.disabled,
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
                        transition: `opacity ${tokens.motion.fast}`,
                    }}
                >
                    <Tooltip title="Reply">
                        <IconButton
                            size="small"
                            onClick={() => onReply?.(message)}
                            sx={{ color: tokens.text.muted }}
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
                px: 2.5,
                py: 1.25,
                display: 'flex',
                alignItems: 'center',
                gap: 1.25,
                bgcolor: tokens.palette.primary[50],
                borderLeft: `3px solid ${tokens.palette.primary[500]}`,
            }}
        >
            <ReplyIcon sx={{ fontSize: 18, color: tokens.palette.primary[600] }} />
            <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="caption" sx={{ fontWeight: 700, display: 'block', color: tokens.palette.primary[700] }}>
                    Replying to {replyingTo.sender?.fullName || ''}
                </Typography>
                <Typography
                    variant="caption"
                    noWrap
                    sx={{ display: 'block', color: tokens.text.secondary }}
                >
                    {previewFromMessage(replyingTo)}
                </Typography>
            </Box>
            <IconButton size="small" onClick={onCancel} sx={{ color: tokens.text.muted }}>
                <CloseIcon fontSize="small" />
            </IconButton>
        </Box>
    );
};

// ---------------------- Main page ----------------------

const EventChats = () => {
    const { user } = useAuth();
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
    const [chatSearch, setChatSearch] = useState('');
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
    const deferredChatSearch = useDeferredValue(chatSearch);

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
            toast.error('Could not load chat groups');
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
                toast.error('Could not load messages');
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
                            ? { ...m, deleted: true, content: 'Message deleted' }
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
                
                // Messenger effect: Remove, Update, and let useMemo/Sorting handle position
                const next = [...prev];
                next[idx] = updated;
                
                // Re-sort immediately to ensure it jumps to top (or after pinned)
                return next.sort((a, b) => {
                    if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
                    const getTs = (c) => (c.lastMessageAt ? new Date(c.lastMessageAt).getTime() : 0);
                    return getTs(b) - getTs(a);
                });
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
                    toast.error('Could not join chat group');
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
            toast.error(backendMsg || 'Could not send message');
        } finally {
            setSending(false);
        }
    }, [draft, selectedId, sending, replyingTo]);

    const handleDelete = useCallback(async (message) => {
        const isMe = message.sender?.id === user?.id;
        try {
            if (isMe) {
                await chatApi.deleteMessage(message.id);
            } else {
                await organiserApi.deleteAnyMessage(message.id);
            }
            setMessages((prev) =>
                prev.map((m) =>
                    m.id === message.id
                        ? { ...m, deleted: true, content: 'Message deleted' }
                        : m,
                ),
            );
            toast.success('Message deleted');
        } catch {
            toast.error('Could not delete message');
        }
    }, [user?.id]);

    const handlePin = useCallback(async (message) => {
        if (!selectedId) return;
        try {
            await organiserApi.pinMessage(selectedId, message.id);
            setChats(prev => prev.map(c => c.conversationId === selectedId ? {
                ...c,
                pinnedMessage: {
                    id: message.id,
                    content: message.content,
                    senderName: message.sender?.fullName || 'Unknown'
                }
            } : c));
            toast.success('Message pinned');
        } catch (err) {
            toast.error('Could not pin message');
        }
    }, [selectedId]);

    const handleUnpin = useCallback(async () => {
        if (!selectedId) return;
        try {
            await organiserApi.unpinMessage(selectedId);
            setChats(prev => prev.map(c => c.conversationId === selectedId ? { ...c, pinnedMessage: null } : c));
            toast.success('Message unpinned');
        } catch (err) {
            toast.error('Could not unpin message');
        }
    }, [selectedId]);

    const handleBan = useCallback(async (userId) => {
        if (!selectedId || !userId || !window.confirm('Ban this user from the event chat?')) return;
        try {
            await organiserApi.banUser(selectedId, userId);
            toast.success('User banned from chat');
        } catch (err) {
            toast.error('Could not ban user');
        }
    }, [selectedId]);

    const handleMute = useCallback(async (userId) => {
        if (!selectedId || !userId || !window.confirm('Mute this user?')) return;
        try {
            await organiserApi.muteUser(selectedId, userId, true);
            toast.success('User muted successfully');
        } catch (err) {
            toast.error('Could not mute user');
        }
    }, [selectedId]);

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

    const filteredChats = useMemo(() => {
        const query = normalizeSearchText(deferredChatSearch);
        let list = [...chats];

        if (query) {
            list = list.filter((chat) => {
                const searchHaystack = normalizeSearchText([
                    chat.eventTitle,
                    chat.lastMessageContent,
                    chat.venue,
                ].filter(Boolean).join(' '));
                return searchHaystack.includes(query);
            });
        }

        // Professional Sorting Logic (Messenger-style)
        return list.sort((a, b) => {
            // 1. Pinned priority
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
            
            // 2. Time priority (Newest first)
            const getTs = (c) => {
                if (!c.lastMessageAt) return 0;
                const d = new Date(c.lastMessageAt);
                return isNaN(d.getTime()) ? 0 : d.getTime();
            };
            
            return getTs(b) - getTs(a);
        });
    }, [chats, deferredChatSearch]);

    const currentTypingNames = Object.values(typingUsers)
        .filter((t) => t.conversationId === selectedId)
        .map((t) => t.name)
        .filter(Boolean);

    const renderedMessages = useMemo(() => {
        // Force sort to ensure newest is always at the bottom
        const sorted = [...messages].sort((a, b) => 
            new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
        );

        const out = [];
        let lastDate = null;
        const pinnedId = selectedChat?.pinnedMessage?.id;

        for (let i = 0; i < sorted.length; i += 1) {
            const m = sorted[i];
            const msgDate = m.createdAt ? new Date(m.createdAt) : null;
            if (msgDate && (!lastDate || !isSameDay(lastDate, msgDate))) {
                out.push({ type: 'separator', key: `sep-${m.id || i}`, date: m.createdAt });
                lastDate = msgDate;
            }
            const prev = sorted[i - 1];
            const next = sorted[i + 1];
            const sameSenderAsPrev =
                prev && prev.sender?.id === m.sender?.id && !prev.deleted;
            const sameSenderAsNext =
                next && next.sender?.id === m.sender?.id;
            const isMe = m.sender?.id === user?.id;
            const isFromOrganiser = m.senderRole === 'ORGANISER';
            out.push({
                type: 'message',
                key: m.id || i,
                message: m,
                isMe,
                isOrganiser: isFromOrganiser,
                isPinned: m.id === pinnedId,
                showAvatar: !isMe && !sameSenderAsNext,
                showName: !isMe && !sameSenderAsPrev,
            });
        }
        return out;
    }, [messages, user?.id, selectedChat?.pinnedMessage]);

    return (
        <Box sx={{ height: 'calc(100vh - 140px)', display: 'flex', flexDirection: 'column' }}>
            <PageHeader
                title="Event Group Chats"
                subtitle="Chat in event groups for events you organize or attend · realtime sync with mobile."
                icon={<ChatIcon />}
                dense
                actions={
                    <Stack direction="row" spacing={1} alignItems="center">
                        <Chip
                            size="small"
                            icon={connected ? <OnlineIcon sx={{ fontSize: 14 }} /> : <OfflineIcon sx={{ fontSize: 14 }} />}
                            label={connected ? 'Realtime' : 'Disconnected'}
                            color={connected ? 'success' : 'default'}
                            variant="outlined"
                            sx={{ fontWeight: 600 }}
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
                }
            />

            <Paper
                elevation={0}
                sx={{
                    flex: 1,
                    display: 'flex',
                    overflow: 'hidden',
                    border: `1px solid ${tokens.borders.subtle}`,
                    borderRadius: `${tokens.radius.xl}px`,
                    bgcolor: tokens.surfaces.card,
                    boxShadow: tokens.shadow.sm,
                }}
            >
                {/* Sidebar */}
                <Box
                    sx={{
                        width: 360,
                        borderRight: `1px solid ${tokens.borders.subtle}`,
                        display: 'flex',
                        flexDirection: 'column',
                        bgcolor: tokens.surfaces.card,
                    }}
                >
                    <Stack
                        direction="row"
                        alignItems="center"
                        spacing={1.25}
                        sx={{
                            px: 2.5,
                            py: 2,
                            borderBottom: `1px solid ${tokens.borders.subtle}`,
                            background: tokens.gradient.primarySoft,
                        }}
                    >
                        <Box
                            sx={{
                                width: 36,
                                height: 36,
                                borderRadius: `${tokens.radius.md}px`,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                background: tokens.gradient.primary,
                                color: '#fff',
                                boxShadow: tokens.shadow.primaryGlow,
                            }}
                        >
                            <GroupsIcon sx={{ fontSize: 20 }} />
                        </Box>
                        <Box sx={{ flex: 1 }}>
                            <Typography variant="subtitle1" sx={{ fontWeight: 700, lineHeight: 1.2, color: tokens.text.strong }}>
                                Event Groups
                            </Typography>
                            <Typography variant="caption" sx={{ color: tokens.text.muted }}>
                                {filteredChats.length}/{chats.length} groups
                            </Typography>
                        </Box>
                    </Stack>

                    <Box
                        sx={{
                            px: 2,
                            py: 1.75,
                            borderBottom: `1px solid ${tokens.borders.subtle}`,
                            bgcolor: tokens.surfaces.card,
                        }}
                    >
                        <Stack spacing={1.25}>
                            <Box
                                sx={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 1,
                                    px: 1.5,
                                    py: 1.15,
                                    borderRadius: `${tokens.radius.md}px`,
                                    bgcolor: tokens.palette.neutral[50],
                                    border: `1px solid ${tokens.borders.subtle}`,
                                    transition: `all ${tokens.motion.fast}`,
                                    '&:focus-within': {
                                        bgcolor: tokens.surfaces.card,
                                        borderColor: tokens.palette.primary[500],
                                        boxShadow: tokens.shadow.focus,
                                    },
                                }}
                            >
                                <SearchIcon sx={{ fontSize: 18, color: tokens.text.muted }} />
                                <InputBase
                                    value={chatSearch}
                                    onChange={(e) => setChatSearch(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter' && filteredChats.length > 0) {
                                            e.preventDefault();
                                            handleSelect(filteredChats[0]);
                                        }
                                    }}
                                    placeholder="Search by event title, preview, status..."
                                    sx={{
                                        flex: 1,
                                        fontSize: 13,
                                        '& input::placeholder': {
                                            color: tokens.text.muted,
                                            opacity: 1,
                                        },
                                    }}
                                />
                                {chatSearch.trim() && (
                                    <IconButton
                                        size="small"
                                        onClick={() => setChatSearch('')}
                                        sx={{ color: tokens.text.muted }}
                                    >
                                        <CloseIcon fontSize="small" />
                                    </IconButton>
                                )}
                            </Box>

                            <Stack
                                direction="row"
                                alignItems="center"
                                justifyContent="space-between"
                            >
                                <Typography variant="caption" sx={{ color: tokens.text.muted, fontSize: '0.7rem' }}>
                                    {chatSearch.trim()
                                        ? `Found ${filteredChats.length} results`
                                        : 'Type to filter · Enter to open top'}
                                </Typography>
                                {totalUnread > 0 && (
                                    <Chip
                                        size="small"
                                        label={`${totalUnread} unread`}
                                        sx={{
                                            height: 22,
                                            fontSize: 11,
                                            fontWeight: 700,
                                            bgcolor: tokens.palette.primary[50],
                                            color: tokens.palette.primary[700],
                                            border: `1px solid ${tokens.palette.primary[200]}`,
                                        }}
                                    />
                                )}
                            </Stack>
                        </Stack>
                    </Box>

                    <Box sx={{ flex: 1, overflowY: 'auto' }}>
                        {loadingChats ? (
                            <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
                                <CircularProgress size={24} sx={{ color: tokens.palette.primary[500] }} />
                            </Box>
                        ) : chats.length === 0 ? (
                            <Box sx={{ p: 5, textAlign: 'center' }}>
                                <Box
                                    sx={{
                                        width: 56,
                                        height: 56,
                                        borderRadius: `${tokens.radius.lg}px`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        bgcolor: tokens.palette.neutral[100],
                                        mb: 1.5,
                                    }}
                                >
                                    <EventIcon sx={{ fontSize: 28, color: tokens.text.disabled }} />
                                </Box>
                                <Typography variant="body2" sx={{ color: tokens.text.secondary }}>
                                    No event groups yet.
                                </Typography>
                            </Box>
                        ) : filteredChats.length === 0 ? (
                            <Box sx={{ p: 5, textAlign: 'center' }}>
                                <Box
                                    sx={{
                                        width: 56,
                                        height: 56,
                                        borderRadius: `${tokens.radius.lg}px`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        bgcolor: tokens.palette.neutral[100],
                                        mb: 1.5,
                                    }}
                                >
                                    <SearchIcon sx={{ fontSize: 28, color: tokens.text.disabled }} />
                                </Box>
                                <Typography variant="subtitle2" sx={{ fontWeight: 700, color: tokens.text.strong }}>
                                    No groups found
                                </Typography>
                                <Typography variant="caption" sx={{ mt: 0.5, display: 'block', color: tokens.text.secondary }}>
                                    Try event title or clear keywords.
                                </Typography>
                            </Box>
                        ) : (
                            <List disablePadding sx={{ p: 1.5 }}>
                                {filteredChats.map((chat) => {
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
                                                px: 1.75,
                                                mb: 0.75,
                                                border: `1px solid`,
                                                borderColor: isSelected
                                                    ? tokens.palette.primary[200]
                                                    : tokens.borders.subtle,
                                                borderRadius: `${tokens.radius.lg}px`,
                                                gap: 1.25,
                                                backgroundColor: isSelected
                                                    ? tokens.palette.primary[50]
                                                    : tokens.surfaces.card,
                                                boxShadow: isSelected
                                                    ? tokens.shadow.md
                                                    : tokens.shadow.xs,
                                                transition: `all ${tokens.motion.fast}`,
                                                '&:hover': {
                                                    bgcolor: isSelected
                                                        ? tokens.palette.primary[50]
                                                        : tokens.palette.neutral[50],
                                                    borderColor: tokens.palette.primary[200],
                                                    boxShadow: tokens.shadow.sm,
                                                    transform: 'translateY(-1px)',
                                                },
                                                '&.Mui-selected': {
                                                    bgcolor: tokens.palette.primary[50],
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
                                                                    bgcolor: tokens.text.disabled,
                                                                    border: `2px solid ${tokens.surfaces.card}`,
                                                                }}
                                                            />
                                                        ) : null
                                                    }
                                                >
                                                    <Avatar
                                                        src={chat.eventImageUrl}
                                                        variant="rounded"
                                                        sx={{
                                                            bgcolor: tokens.palette.primary[100],
                                                            color: tokens.palette.primary[700],
                                                            width: 46,
                                                            height: 46,
                                                            borderRadius: `${tokens.radius.md}px`,
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
                                                                color: tokens.text.strong,
                                                            }}
                                                        >
                                                            {chat.eventTitle}
                                                        </Typography>
                                                        <Typography
                                                            variant="caption"
                                                            sx={{
                                                                fontWeight: unread > 0 ? 700 : 400,
                                                                color: unread > 0 ? tokens.palette.primary[600] : tokens.text.muted,
                                                                flexShrink: 0,
                                                            }}
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
                                                        sx={{ mt: 0.5 }}
                                                    >
                                                        <Typography
                                                            variant="caption"
                                                            sx={{
                                                                flex: 1,
                                                                overflow: 'hidden',
                                                                textOverflow: 'ellipsis',
                                                                whiteSpace: 'nowrap',
                                                                fontWeight: unread > 0 ? 600 : 400,
                                                                color: unread > 0 ? tokens.text.primary : tokens.text.muted,
                                                            }}
                                                        >
                                                            {chat.lastMessageContent ||
                                                                (chat.joined
                                                                    ? 'No messages yet'
                                                                    : 'Click to join')}
                                                        </Typography>
                                                        {unread > 0 && (
                                                            <Box
                                                                sx={{
                                                                    minWidth: 22,
                                                                    height: 22,
                                                                    px: 1,
                                                                    borderRadius: tokens.radius.pill,
                                                                    background: tokens.gradient.primary,
                                                                    color: '#fff',
                                                                    display: 'flex',
                                                                    alignItems: 'center',
                                                                    justifyContent: 'center',
                                                                    fontSize: 11,
                                                                    fontWeight: 700,
                                                                    boxShadow: tokens.shadow.primaryGlow,
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
                <Box
                    sx={{
                        flex: 1,
                        display: 'flex',
                        flexDirection: 'column',
                        bgcolor: tokens.palette.neutral[50],
                    }}
                >
                    {!selectedChat ? (
                        <EmptyChat />
                    ) : (
                        <>
                            <Stack
                                direction="row"
                                alignItems="center"
                                spacing={1.5}
                                sx={{
                                    px: 3,
                                    py: 1.75,
                                    borderBottom: `1px solid ${tokens.borders.subtle}`,
                                    bgcolor: tokens.surfaces.card,
                                    boxShadow: tokens.shadow.xs,
                                }}
                            >
                                <Avatar
                                    src={selectedChat.eventImageUrl}
                                    variant="rounded"
                                    sx={{
                                        bgcolor: tokens.palette.primary[100],
                                        color: tokens.palette.primary[700],
                                        width: 42,
                                        height: 42,
                                        borderRadius: `${tokens.radius.md}px`,
                                    }}
                                >
                                    <EventIcon />
                                </Avatar>
                                <Box sx={{ flex: 1, minWidth: 0 }}>
                                    <Typography variant="subtitle1" sx={{ fontWeight: 700, color: tokens.text.strong }} noWrap>
                                        {selectedChat.eventTitle}
                                    </Typography>
                                    <Stack direction="row" alignItems="center" spacing={0.75}>
                                        <Typography variant="caption" sx={{ color: tokens.text.muted }}>
                                            {selectedChat.participantCount || 0} members
                                        </Typography>
                                        {selectedChat.closed && (
                                            <>
                                                <Box sx={{ width: 3, height: 3, bgcolor: tokens.text.disabled, borderRadius: '50%' }} />
                                                <Typography variant="caption" sx={{ color: tokens.palette.danger[600], fontWeight: 600 }}>
                                                    Closed
                                                </Typography>
                                            </>
                                        )}
                                        {currentTypingNames.length > 0 && (
                                            <>
                                                <Box sx={{ width: 3, height: 3, bgcolor: tokens.text.disabled, borderRadius: '50%' }} />
                                                <Typography variant="caption" sx={{ fontStyle: 'italic', color: tokens.palette.primary[600] }}>
                                                    {currentTypingNames.length === 1
                                                        ? `${currentTypingNames[0]} is typing`
                                                        : `${currentTypingNames.length} people are typing`}
                                                </Typography>
                                                <TypingDots />
                                            </>
                                        )}
                                    </Stack>
                                </Box>
                            </Stack>

                            {selectedChat.pinnedMessage && (
                                <Box
                                    sx={{
                                        px: 3,
                                        py: 1,
                                        bgcolor: tokens.palette.primary[50],
                                        borderBottom: `1px solid ${tokens.borders.subtle}`,
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: 2,
                                        cursor: 'pointer',
                                        transition: 'background 0.2s',
                                        '&:hover': { bgcolor: tokens.palette.primary[100] }
                                    }}
                                    onClick={() => {
                                        const el = document.getElementById(`msg-${selectedChat.pinnedMessage.id}`);
                                        if (el) {
                                            el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                            el.style.backgroundColor = tokens.palette.primary[50];
                                            setTimeout(() => {
                                                el.style.backgroundColor = '';
                                            }, 2000);
                                        } else {
                                            toast.info('This message is old, please scroll up to find it');
                                        }
                                    }}
                                >
                                    <ReplyIcon sx={{ transform: 'rotate(90deg)', fontSize: 16, color: tokens.palette.primary[600] }} />
                                    <Box sx={{ flex: 1, minWidth: 0 }}>
                                        <Typography variant="caption" sx={{ fontWeight: 700, color: tokens.palette.primary[700], display: 'block' }}>
                                            Pinned Message
                                        </Typography>
                                        <Typography variant="caption" sx={{ color: tokens.text.secondary }} noWrap>
                                            {selectedChat.pinnedMessage.senderName}: {selectedChat.pinnedMessage.content}
                                        </Typography>
                                    </Box>
                                    <IconButton size="small" onClick={(e) => {
                                        e.stopPropagation();
                                        handleUnpin(selectedChat.pinnedMessage);
                                    }}>
                                        <CloseIcon fontSize="small" />
                                    </IconButton>
                                </Box>
                            )}

                            <Box
                                ref={messagesScrollRef}
                                onScroll={handleScroll}
                                sx={{
                                    flex: 1,
                                    overflowY: 'auto',
                                    py: 2.5,
                                    px: { xs: 1.5, md: 2.5 },
                                    position: 'relative',
                                }}
                            >
                                <Box sx={{ width: '100%', maxWidth: 900, mx: 'auto' }}>
                                    {loadingMore && (
                                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 1.5 }}>
                                            <CircularProgress size={18} sx={{ color: tokens.palette.primary[400] }} />
                                        </Box>
                                    )}
                                    {loadingMessages ? (
                                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
                                            <CircularProgress size={28} sx={{ color: tokens.palette.primary[500] }} />
                                        </Box>
                                    ) : messages.length === 0 ? (
                                        <Box sx={{ textAlign: 'center', py: 8 }}>
                                            <Box
                                                sx={{
                                                    width: 64,
                                                    height: 64,
                                                    borderRadius: `${tokens.radius.xl}px`,
                                                    display: 'inline-flex',
                                                    alignItems: 'center',
                                                    justifyContent: 'center',
                                                    background: tokens.gradient.primarySoft,
                                                    mb: 2,
                                                }}
                                            >
                                                <ChatIcon sx={{ fontSize: 28, color: tokens.palette.primary[500] }} />
                                            </Box>
                                            <Typography variant="body2" sx={{ color: tokens.text.secondary }}>
                                                No messages yet. Send the first one!
                                            </Typography>
                                        </Box>
                                    ) : (
                                        <Stack spacing={0.75}>
                                            {renderedMessages.map((item) =>
                                                item.type === 'separator' ? (
                                                    <DateSeparator key={item.key} date={item.date} />
                                                ) : (
                                                    <MessageBubble
                                                        key={item.key}
                                                        message={item.message}
                                                        isMe={item.isMe}
                                                        isOrganiser={item.isOrganiser}
                                                        isPinned={item.isPinned}
                                                        showAvatar={item.showAvatar}
                                                        showName={item.showName}
                                                        onReply={setReplyingTo}
                                                        onDelete={handleDelete}
                                                        onPin={handlePin}
                                                        onUnpin={handleUnpin}
                                                        onBan={handleBan}
                                                        onMute={handleMute}
                                                    />
                                                ),
                                            )}
                                            <div ref={messagesEndRef} />
                                        </Stack>
                                    )}
                                </Box>

                                <Fade in={showScrollDown}>
                                    <IconButton
                                        onClick={scrollToBottom}
                                        size="small"
                                        sx={{
                                            position: 'sticky',
                                            bottom: 12,
                                            left: '50%',
                                            ml: '-20px',
                                            bgcolor: tokens.surfaces.card,
                                            boxShadow: tokens.shadow.md,
                                            border: `1px solid ${tokens.borders.subtle}`,
                                            '&:hover': { bgcolor: tokens.palette.neutral[50] },
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
                                        borderTop: `1px solid ${tokens.borders.subtle}`,
                                        bgcolor: tokens.palette.info[50],
                                        color: tokens.palette.info[700],
                                    }}
                                >
                                    Chat group is closed. Cannot send messages.
                                </Alert>
                            ) : (
                                <Box
                                    sx={{
                                        bgcolor: tokens.surfaces.card,
                                        borderTop: `1px solid ${tokens.borders.subtle}`,
                                        boxShadow: `0 -2px 8px rgba(15,23,42,0.03)`,
                                    }}
                                >
                                    <ReplyPreview
                                        replyingTo={replyingTo}
                                        onCancel={() => setReplyingTo(null)}
                                    />
                                    <Stack
                                        direction="row"
                                        spacing={1}
                                        alignItems="flex-end"
                                        sx={{ px: 2.5, py: 1.5 }}
                                    >
                                        <Tooltip title="Emoji">
                                            <IconButton
                                                size="small"
                                                onClick={(e) => setEmojiAnchor(e.currentTarget)}
                                                sx={{
                                                    color: tokens.text.muted,
                                                    bgcolor: tokens.palette.neutral[100],
                                                    '&:hover': { bgcolor: tokens.palette.neutral[200] },
                                                }}
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
                                                    gridTemplateColumns: 'repeat(8, 36px)',
                                                    gap: 0.5,
                                                    p: 1.5,
                                                    maxWidth: 320,
                                                }}
                                            >
                                                {EMOJIS.map((emoji) => (
                                                    <IconButton
                                                        key={emoji}
                                                        size="small"
                                                        onClick={() => handleEmojiPick(emoji)}
                                                        sx={{
                                                            width: 36,
                                                            height: 36,
                                                            fontSize: 20,
                                                            p: 0,
                                                            borderRadius: `${tokens.radius.sm}px`,
                                                            '&:hover': { bgcolor: tokens.palette.neutral[100] },
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
                                            placeholder="Type a message... (Enter to send, Shift+Enter for new line)"
                                            multiline
                                            maxRows={5}
                                            sx={{
                                                flex: 1,
                                                px: 2.5,
                                                py: 1.25,
                                                borderRadius: `${tokens.radius.xl}px`,
                                                bgcolor: tokens.palette.neutral[50],
                                                fontSize: 14,
                                                border: `1px solid ${tokens.borders.subtle}`,
                                                transition: `all ${tokens.motion.fast}`,
                                                '&:focus-within': {
                                                    borderColor: tokens.palette.primary[500],
                                                    bgcolor: tokens.surfaces.card,
                                                    boxShadow: tokens.shadow.focus,
                                                },
                                                '& input::placeholder, & textarea::placeholder': {
                                                    color: tokens.text.muted,
                                                    opacity: 1,
                                                },
                                            }}
                                        />
                                        <Tooltip title="Send">
                                            <span>
                                                <IconButton
                                                    onClick={handleSend}
                                                    disabled={!draft.trim() || sending}
                                                    sx={{
                                                        background: tokens.gradient.primary,
                                                        color: '#fff',
                                                        width: 44,
                                                        height: 44,
                                                        borderRadius: `${tokens.radius.lg}px`,
                                                        boxShadow: tokens.shadow.primaryGlow,
                                                        transition: `all ${tokens.motion.fast}`,
                                                        '&:hover': {
                                                            background: tokens.gradient.primary,
                                                            filter: 'brightness(1.1)',
                                                            boxShadow: tokens.shadow.lg,
                                                        },
                                                        '&:disabled': {
                                                            background: tokens.palette.neutral[200],
                                                            color: tokens.text.disabled,
                                                            boxShadow: 'none',
                                                        },
                                                    }}
                                                >
                                                    {sending ? (
                                                        <CircularProgress
                                                            size={18}
                                                            sx={{ color: '#fff' }}
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
