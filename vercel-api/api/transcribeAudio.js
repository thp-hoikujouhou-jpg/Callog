/**
 * Vercel API Endpoint: Audio Transcription with Google Cloud Speech-to-Text
 * 
 * This endpoint downloads audio from Firebase Storage and transcribes it using 
 * Google Cloud Speech-to-Text API (専用の音声認識API) with Service Account authentication.
 * 
 * Benefits:
 * - ✅ Dedicated speech recognition API (not general-purpose LLM)
 * - ✅ Production-grade stability with Service Account
 * - ✅ High-accuracy Japanese support
 * - ✅ Native WebM format support
 * - ✅ No API key management needed
 */

import fetch from 'node-fetch';
import { SpeechClient } from '@google-cloud/speech';

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
    
    console.log('[TranscribeAudio] 🎙️ Starting transcription...');
    console.log('[TranscribeAudio]    Audio URL:', audioUrl);
    console.log('[TranscribeAudio]    Format:', audioFormat);

    // Validate required parameters
    if (!audioUrl || !audioFormat) {
      return res.status(400).json({ 
        error: 'Missing required parameters', 
        required: ['audioUrl', 'audioFormat'] 
      });
    }

    // Initialize Google Cloud Speech client with Firebase service account
    // Use existing FIREBASE_SERVICE_ACCOUNT (Base64 encoded)
    let speechClient;
    
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      console.log('[TranscribeAudio] 🔑 Using Firebase Service Account (Base64)');
      // Decode Base64 to get JSON string
      const serviceAccountJson = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf-8');
      const credentials = JSON.parse(serviceAccountJson);
      console.log('[TranscribeAudio] 📧 Service Account Email:', credentials.client_email);
      speechClient = new SpeechClient({ credentials });
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
      console.log('[TranscribeAudio] 🔑 Using GOOGLE_APPLICATION_CREDENTIALS_JSON');
      const credentials = JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
      speechClient = new SpeechClient({ credentials });
    } else {
      console.log('[TranscribeAudio] 🔑 Using default Google Cloud credentials');
      speechClient = new SpeechClient(); // Fallback to default credentials
    }

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

    console.log('[TranscribeAudio] 🤖 Sending to Google Cloud Speech-to-Text API...');

    // Prepare Speech-to-Text request (高品質設定)
    const request = {
      audio: {
        content: audioBytes.toString('base64'),
      },
      config: {
        encoding: audioFormat === 'webm' ? 'WEBM_OPUS' : 'MP4',
        sampleRateHertz: 48000, // 48kHz (録音設定と一致)
        languageCode: 'ja-JP',  // Japanese
        enableAutomaticPunctuation: true, // 句読点自動挿入
        model: 'latest_long',   // 最新・長時間対応モデル
        useEnhanced: true,      // 拡張モデル使用 (精度向上)
        // audioChannelCount: Unspecified (自動検出 - WEBM ヘッダから取得)
      },
    };

    // Perform speech recognition
    const [response] = await speechClient.recognize(request);
    
    console.log('[TranscribeAudio] 📄 Raw API Response:', JSON.stringify(response, null, 2));

    // Extract transcription from results
    if (!response.results || response.results.length === 0) {
      console.warn('[TranscribeAudio] ⚠️ No transcription results returned');
      return res.status(500).json({ error: 'No transcription results' });
    }

    // Concatenate all alternatives (usually only one)
    const transcription = response.results
      .map(result => result.alternatives[0].transcript)
      .join('\n');

    if (!transcription || transcription.trim().length === 0) {
      console.warn('[TranscribeAudio] ⚠️ Empty transcription result');
      return res.status(500).json({ error: 'Empty transcription result' });
    }

    console.log('[TranscribeAudio] ✅ Transcription completed');
    console.log('[TranscribeAudio]    Length:', transcription.length, 'characters');

    // Get confidence score
    const confidence = response.results[0]?.alternatives[0]?.confidence || null;

    // Return transcription
    return res.status(200).json({ 
      transcription: transcription,
      audioFormat: audioFormat,
      audioSize: audioBytes.length,
      confidence: confidence,
    });

  } catch (error) {
    console.error('[TranscribeAudio] ❌ Error:', error);
    return res.status(500).json({ 
      error: 'Transcription failed', 
      message: error.message,
      stack: error.stack,
    });
  }
}
