// Chat-related TypeScript types

export interface Message {
    id: string;
    groupId: string;
    senderId: string;
    content: string | null;
    messageType: MessageType;
    fileUrl: string | null;
    fileName: string | null;
    replyToId: string | null;
    createdAt: Date;
    updatedAt: Date;
    // Populated fields
    sender?: MessageSender;
    replyTo?: ReplyMessage | null;
}

export interface MessageSender {
    id: string;
    displayName: string | null;
    avatarUrl: string | null;
}

export interface ReplyMessage {
    id: string;
    content: string | null;
    messageType: MessageType;
    sender: MessageSender;
}

export type MessageType = 'TEXT' | 'IMAGE' | 'FILE';

export interface SendMessageRequest {
    content?: string;
    messageType: MessageType;
    fileUrl?: string;
    fileName?: string;
    replyToId?: string;
}

export interface GetMessagesResponse {
    messages: Message[];
    hasMore: boolean;
}

// Socket events
export interface ServerToClientEvents {
    new_message: (message: Message) => void;
    new_notification: (notification: {
        id: string;
        type: string;
        title: string;
        message: string;
        data?: any;
        read: boolean;
        createdAt: Date;
    }) => void;
    user_typing: (data: { userId: string; displayName: string; groupId: string }) => void;
    user_stop_typing: (data: { userId: string; groupId: string }) => void;
    error: (error: { message: string; code: string }) => void;
}

export interface ClientToServerEvents {
    join_group: (groupId: string) => void;
    leave_group: (groupId: string) => void;
    send_message: (data: { groupId: string } & SendMessageRequest) => void;
    typing: (groupId: string) => void;
    stop_typing: (groupId: string) => void;
}

export interface ApiResponse<T> {
    success: boolean;
    data?: T;
    error?: {
        message: string;
        code: string;
    };
}
