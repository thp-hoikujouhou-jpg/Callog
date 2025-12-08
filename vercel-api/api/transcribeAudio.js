/**
 * Vercel API Endpoint: Audio Transcription with Google Cloud Speech-to-Text
 * 
 * This endpoint downloads audio from Firebase Storage and transcribes it using 
 * Google Cloud Speech-to-Text API (専用の文字起こしAPI).
 */

import { SpeechClient } from '@google-cloud/speech';
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
    const { audioUrl, audioFormat, languageCode = 'ja-JP' } = req.body;
    
    // Get Google Cloud credentials from environment variable
    const credentialsJson = process.env.GOOGLE_CLOUD_CREDENTIALS;

    console.log('[TranscribeAudio] 🔑 Credentials check:', credentialsJson ? '✅ Available' : '❌ Missing');

    // Validate required parameters
    if (!audioUrl || !audioFormat) {
      return res.status(400).json({ 
        error: 'Missing required parameters', 
        required: ['audioUrl', 'audioFormat'] 
      });
    }
    
    if (!credentialsJson) {
      return res.status(500).json({
        error: 'GOOGLE_CLOUD_CREDENTIALS not configured in environment variables'
      });
    }

    console.log('[TranscribeAudio] 🎙️ Starting transcription...');
    console.log('[TranscribeAudio]    Audio URL:', audioUrl);
    console.log('[TranscribeAudio]    Format:', audioFormat);
    console.log('[TranscribeAudio]    Language:', languageCode);

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

    // Initialize Speech-to-Text client with credentials
    const credentials = JSON.parse(credentialsJson);
    const client = new SpeechClient({ credentials });

    console.log('[TranscribeAudio] 🤖 Sending to Google Cloud Speech-to-Text...');

    // Configure audio recognition request
    const audio = {
      content: audioBytes.toString('base64'),
    };

    const config = {
      encoding: audioFormat === 'webm' ? 'WEBM_OPUS' : 'LINEAR16',
      sampleRateHertz: 48000, // Web Audio standard sample rate
      languageCode: languageCode,
      enableAutomaticPunctuation: true, // 句読点の自動挿入
      enableSpeakerDiarization: true,   // 話者分離
      diarizationSpeakerCount: 2,       // 最大2名の話者を想定
      model: 'default',                 // 最新の汎用モデル
    };

    const request = {
      audio: audio,
      config: config,
    };

    // Perform transcription
    const [response] = await client.recognize(request);
    
    if (!response.results || response.results.length === 0) {
      console.warn('[TranscribeAudio] ⚠️ Empty transcription result');
      return res.status(500).json({ error: 'Empty transcription result' });
    }

    // Extract transcription text with speaker labels
    const transcription = response.results
      .map(result => {
        const alternative = result.alternatives[0];
        if (result.words && result.words[0].speakerTag) {
          // 話者タグがある場合
          const speakerTag = result.words[0].speakerTag;
          return `[話者${speakerTag}]: ${alternative.transcript}`;
        }
        return alternative.transcript;
      })
      .join('\n');

    console.log('[TranscribeAudio] ✅ Transcription completed');
    console.log('[TranscribeAudio]    Length:', transcription.length, 'characters');
    console.log('[TranscribeAudio]    Results count:', response.results.length);

    // Return transcription
    return res.status(200).json({ 
      transcription: transcription,
      audioFormat: audioFormat,
      audioSize: audioBytes.length,
      languageCode: languageCode,
      resultsCount: response.results.length,
    });

  } catch (error) {
    console.error('[TranscribeAudio] ❌ Error:', error);
    return res.status(500).json({ 
      error: 'Transcription failed', 
      message: error.message 
    });
  }
}
