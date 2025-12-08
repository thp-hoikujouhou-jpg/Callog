/**
 * Vercel API Endpoint: Audio Transcription with Gemini AI
 * 
 * This endpoint downloads audio from Firebase Storage and transcribes it using Gemini AI.
 * It bypasses CORS issues by running server-side.
 */

import { GoogleGenerativeAI } from '@google/generative-ai';
import fetch from 'node-fetch';

export default async function handler(req, res) {
  // Set CORS headers (Allow requests from any origin)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // Handle OPTIONS preflight request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { audioUrl, audioFormat } = req.body;
    
    // Get Gemini API Key from environment variable (priority) or request body (fallback)
    const apiKey = process.env.GEMINI_API_KEY || req.body.apiKey;

    console.log('[TranscribeAudio] 🔑 API Key check:', apiKey ? '✅ Available' : '❌ Missing');

    // Validate required parameters
    if (!audioUrl || !audioFormat) {
      return res.status(400).json({ 
        error: 'Missing required parameters', 
        required: ['audioUrl', 'audioFormat'] 
      });
    }
    
    if (!apiKey) {
      return res.status(500).json({
        error: 'GEMINI_API_KEY not configured in environment variables or request body'
      });
    }

    console.log('[TranscribeAudio] 🎙️ Starting transcription...');
    console.log('[TranscribeAudio]    Audio URL:', audioUrl);
    console.log('[TranscribeAudio]    Format:', audioFormat);
    console.log('[TranscribeAudio]    API Key source:', process.env.GEMINI_API_KEY ? 'Environment Variable' : 'Request Body');

    // Download audio file from Firebase Storage
    console.log('[TranscribeAudio] 📥 Downloading audio file...');
    const audioResponse = await fetch(audioUrl);
    
    if (!audioResponse.ok) {
      console.error('[TranscribeAudio] ❌ Failed to download audio:', audioResponse.status);
      return res.status(500).json({ 
        error: 'Failed to download audio file',
        status: audioResponse.status 
      });
    }

    const audioBuffer = await audioResponse.arrayBuffer();
    const audioBytes = Buffer.from(audioBuffer);
    
    console.log('[TranscribeAudio] ✅ Audio downloaded:', audioBytes.length, 'bytes');

    // Initialize Gemini AI
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    console.log('[TranscribeAudio] 🤖 Sending to Gemini AI...');

    // Determine MIME type
    const mimeType = audioFormat === 'webm' ? 'audio/webm' : 'audio/m4a';

    // Create prompt and audio part
    const prompt = `音声ファイルの内容を正確に文字起こししてください。
会話の内容をそのまま文字に起こし、話者が複数いる場合は区別してください。
句読点や改行を適切に挿入して、読みやすい形式にしてください。`;

    const audioPart = {
      inlineData: {
        data: audioBytes.toString('base64'),
        mimeType: mimeType,
      },
    };

    // Generate transcription
    const result = await model.generateContent([prompt, audioPart]);
    const transcription = result.response.text();

    if (!transcription || transcription.trim().length === 0) {
      console.warn('[TranscribeAudio] ⚠️ Empty transcription result');
      return res.status(500).json({ error: 'Empty transcription result' });
    }

    console.log('[TranscribeAudio] ✅ Transcription completed');
    console.log('[TranscribeAudio]    Length:', transcription.length, 'characters');

    // Return transcription
    return res.status(200).json({ 
      transcription: transcription,
      audioFormat: audioFormat,
      audioSize: audioBytes.length,
    });

  } catch (error) {
    console.error('[TranscribeAudio] ❌ Error:', error);
    return res.status(500).json({ 
      error: 'Transcription failed', 
      message: error.message 
    });
  }
}
