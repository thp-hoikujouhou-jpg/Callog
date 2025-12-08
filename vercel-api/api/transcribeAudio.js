/**
 * Vercel API Endpoint: Audio Transcription with Google Cloud Speech-to-Text
 * 
 * This endpoint downloads audio from Firebase Storage and transcribes it using 
 * Google Cloud Speech-to-Text API (専用の音声認識API).
 * 
 * Benefits over Gemini:
 * - ✅ Dedicated speech recognition API (not general-purpose LLM)
 * - ✅ Production-grade stability
 * - ✅ High-accuracy Japanese support
 * - ✅ Native WebM format support
 * - ✅ No model version confusion issues
 */

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
    
    // Get Google Cloud API Key from environment variable (priority) or request body (fallback)
    const apiKey = process.env.GOOGLE_CLOUD_API_KEY || req.body.apiKey;

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
        error: 'GOOGLE_CLOUD_API_KEY not configured in environment variables or request body'
      });
    }

    console.log('[TranscribeAudio] 🎙️ Starting transcription...');
    console.log('[TranscribeAudio]    Audio URL:', audioUrl);
    console.log('[TranscribeAudio]    Format:', audioFormat);
    console.log('[TranscribeAudio]    API Key source:', process.env.GOOGLE_CLOUD_API_KEY ? 'Environment Variable' : 'Request Body');

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

    // Google Cloud Speech-to-Text API v1 endpoint
    const speechApiUrl = `https://speech.googleapis.com/v1/speech:recognize?key=${apiKey}`;

    console.log('[TranscribeAudio] 🤖 Sending to Google Cloud Speech-to-Text API...');

    // Prepare request body for Speech-to-Text API
    const requestBody = {
      config: {
        encoding: audioFormat === 'webm' ? 'WEBM_OPUS' : 'MP4', // WebM Opus or MP4/M4A
        sampleRateHertz: 48000, // Standard sample rate for WebM
        languageCode: 'ja-JP', // Japanese
        enableAutomaticPunctuation: true, // 句読点自動挿入
        enableWordTimeOffsets: false, // Word-level timestamps (optional)
        model: 'default', // Use 'default' or 'video' model
      },
      audio: {
        content: audioBytes.toString('base64'), // Base64-encoded audio
      },
    };

    // Send request to Speech-to-Text API
    const speechResponse = await fetch(speechApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });

    if (!speechResponse.ok) {
      const errorText = await speechResponse.text();
      console.error('[TranscribeAudio] ❌ Speech API Error:', speechResponse.status, errorText);
      return res.status(500).json({ 
        error: 'Speech-to-Text API request failed',
        status: speechResponse.status,
        details: errorText,
      });
    }

    const speechResult = await speechResponse.json();
    console.log('[TranscribeAudio] 📄 Raw API Response:', JSON.stringify(speechResult, null, 2));

    // Extract transcription from results
    if (!speechResult.results || speechResult.results.length === 0) {
      console.warn('[TranscribeAudio] ⚠️ No transcription results returned');
      return res.status(500).json({ error: 'No transcription results' });
    }

    // Concatenate all alternatives (usually only one)
    const transcription = speechResult.results
      .map(result => result.alternatives[0].transcript)
      .join('\n');

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
      confidence: speechResult.results[0]?.alternatives[0]?.confidence || null,
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
