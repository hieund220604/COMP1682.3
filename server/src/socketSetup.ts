import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { chatService } from './service/chatService';
import {
    ServerToClientEvents,
    ClientToServerEvents,
    SendMessageRequest
} from './type/chat';

interface AuthenticatedSocket extends Socket<ClientToServerEvents, ServerToClientEvents> {
    userId?: string;
    displayName?: string;
}

interface JwtPayload {
    userId: string;
    email: string;
    displayName?: string;
}

// Export io instance for use in services
let io: Server<ClientToServerEvents, ServerToClientEvents>;

export function getIO(): Server<ClientToServerEvents, ServerToClientEvents> {
    if (!io) {
        throw new Error('Socket.io not initialized. Call setupSocketIO first.');
    }
    return io;
}

export function setupSocketIO(httpServer: HttpServer): Server {
    io = new Server<ClientToServerEvents, ServerToClientEvents>(httpServer, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST']
        },
        transports: ['websocket', 'polling']
    });

    // Authentication middleware
    io.use((socket: AuthenticatedSocket, next) => {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

        if (!token) {
            return next(new Error('Authentication required'));
        }

        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key') as JwtPayload;
            socket.userId = decoded.userId;
            socket.displayName = decoded.displayName || 'Unknown';
            next();
        } catch (error) {
            next(new Error('Invalid token'));
        }
    });

    io.on('connection', (socket: AuthenticatedSocket) => {
        console.log(`User connected: ${socket.userId}`);

        // Auto-join user's personal notification room
        if (socket.userId) {
            socket.join(`user:${socket.userId}`);
        }

        // Join a group chat room
        socket.on('join_group', (groupId: string) => {
            socket.join(`group:${groupId}`);
        });

        // Leave a group chat room
        socket.on('leave_group', (groupId: string) => {
            socket.leave(`group:${groupId}`);
        });

        // Send a message
        socket.on('send_message', async (data: { groupId: string } & SendMessageRequest) => {
            try {
                if (!socket.userId) {
                    socket.emit('error', { message: 'Not authenticated', code: 'AUTH_ERROR' });
                    return;
                }

                const { groupId, ...messageData } = data;

                // Save message to database
                const message = await chatService.saveMessage(groupId, socket.userId, messageData);

                // Broadcast to all users in the group (including sender)
                io.to(`group:${groupId}`).emit('new_message', message);

            } catch (error) {
                console.error('Error sending message:', error);

                if (error instanceof Error && error.message === 'NOT_GROUP_MEMBER') {
                    socket.emit('error', { message: 'You are not a member of this group', code: 'FORBIDDEN' });
                } else {
                    socket.emit('error', { message: 'Failed to send message', code: 'SEND_ERROR' });
                }
            }
        });

        // Typing indicator
        socket.on('typing', (groupId: string) => {
            socket.to(`group:${groupId}`).emit('user_typing', {
                userId: socket.userId!,
                displayName: socket.displayName || 'Unknown',
                groupId
            });
        });

        socket.on('stop_typing', (groupId: string) => {
            socket.to(`group:${groupId}`).emit('user_stop_typing', {
                userId: socket.userId!,
                groupId
            });
        });

        // Disconnect
        socket.on('disconnect', () => {
            console.log(`User disconnected: ${socket.userId}`);
        });
    });

    return io;
}
