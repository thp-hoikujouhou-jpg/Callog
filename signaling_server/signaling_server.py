#!/usr/bin/env python3
import asyncio
import websockets
import json
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Store connected clients: {userId: websocket}
clients = {}

async def handle_client(websocket):
    user_id = None
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get('type')
                
                logger.info(f"Received message: {msg_type} from {user_id or 'unregistered'}")
                
                if msg_type == 'register':
                    user_id = data.get('userId')
                    clients[user_id] = websocket
                    logger.info(f"User registered: {user_id}. Total clients: {len(clients)}")
                    await websocket.send(json.dumps({
                        'type': 'registered',
                        'userId': user_id
                    }))
                
                elif msg_type == 'offer':
                    target_user_id = data.get('targetUserId')
                    if target_user_id in clients:
                        logger.info(f"Forwarding offer from {user_id} to {target_user_id}")
                        await clients[target_user_id].send(json.dumps({
                            'type': 'offer',
                            'offer': data.get('offer'),
                            'fromUserId': user_id
                        }))
                    else:
                        logger.warning(f"Target user {target_user_id} not found")
                        await websocket.send(json.dumps({
                            'type': 'error',
                            'message': 'Target user not available'
                        }))
                
                elif msg_type == 'answer':
                    target_user_id = data.get('targetUserId')
                    if target_user_id in clients:
                        logger.info(f"Forwarding answer from {user_id} to {target_user_id}")
                        await clients[target_user_id].send(json.dumps({
                            'type': 'answer',
                            'answer': data.get('answer'),
                            'fromUserId': user_id
                        }))
                    else:
                        logger.warning(f"Target user {target_user_id} not found")
                
                elif msg_type == 'ice-candidate':
                    target_user_id = data.get('targetUserId')
                    if target_user_id in clients:
                        logger.info(f"Forwarding ICE candidate from {user_id} to {target_user_id}")
                        await clients[target_user_id].send(json.dumps({
                            'type': 'ice-candidate',
                            'candidate': data.get('candidate'),
                            'fromUserId': user_id
                        }))
                
                elif msg_type == 'end-call':
                    target_user_id = data.get('targetUserId')
                    if target_user_id in clients:
                        logger.info(f"Forwarding end-call from {user_id} to {target_user_id}")
                        await clients[target_user_id].send(json.dumps({
                            'type': 'end-call',
                            'fromUserId': user_id
                        }))
                
            except json.JSONDecodeError:
                logger.error(f"Invalid JSON received from {user_id}")
            except Exception as e:
                logger.error(f"Error processing message from {user_id}: {e}")
    
    except websockets.exceptions.ConnectionClosed:
        logger.info(f"Connection closed for user: {user_id}")
    except Exception as e:
        logger.error(f"Error in handle_client for {user_id}: {e}")
    finally:
        if user_id and user_id in clients:
            del clients[user_id]
            logger.info(f"User disconnected: {user_id}. Total clients: {len(clients)}")

async def main():
    logger.info("Starting WebRTC signaling server on port 8765...")
    async with websockets.serve(handle_client, "0.0.0.0", 8765):
        logger.info("✅ Signaling server running on ws://0.0.0.0:8765")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
