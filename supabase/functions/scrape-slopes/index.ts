// Supabase Edge Function to scrape KitzSki slope status
// Deploy with: supabase functions deploy scrape-slopes
// Schedule with: Supabase Dashboard > Database > pg_cron

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const KITZSKI_URL = 'https://www.kitzski.at/de/aktuelle-info/pistenstatus.html'

interface SlopeStatus {
  name: string
  status: 'open' | 'closed' | 'unknown'
  difficulty?: string
}

interface LiftStatus {
  name: string
  status: 'open' | 'closed' | 'unknown'
  type?: string
}

interface ScrapedData {
  slopes: SlopeStatus[]
  lifts: LiftStatus[]
  lastUpdated: string
  source: string
}

Deno.serve(async (req) => {
  try {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }

    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    // Fetch the KitzSki page
    const response = await fetch(KITZSKI_URL, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; SkiTracker/1.0)',
      },
    })

    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.status}`)
    }

    const html = await response.text()
    
    // Parse the HTML (simple regex-based parsing for Edge Functions)
    const slopes: SlopeStatus[] = []
    const lifts: LiftStatus[] = []
    
    // Match slope entries - look for common patterns
    const slopePattern = /<tr[^>]*>.*?<td[^>]*>(.*?)<\/td>.*?<td[^>]*>.*?(geöffnet|geschlossen|offen|closed|open).*?<\/td>.*?<\/tr>/gis
    let match
    
    while ((match = slopePattern.exec(html)) !== null) {
      const name = match[1].replace(/<[^>]+>/g, '').trim()
      const statusText = match[2].toLowerCase()
      
      if (name && name.length < 100) {
        slopes.push({
          name,
          status: statusText.includes('geöffnet') || statusText.includes('offen') || statusText.includes('open') 
            ? 'open' 
            : 'closed'
        })
      }
    }

    // Match lift entries
    const liftPattern = /<tr[^>]*>.*?<td[^>]*>(.*?(?:bahn|lift|gondel|sessellift).*?)<\/td>.*?<td[^>]*>.*?(geöffnet|geschlossen|offen|closed|open).*?<\/td>.*?<\/tr>/gis
    
    while ((match = liftPattern.exec(html)) !== null) {
      const name = match[1].replace(/<[^>]+>/g, '').trim()
      const statusText = match[2].toLowerCase()
      
      if (name && name.length < 100) {
        lifts.push({
          name,
          status: statusText.includes('geöffnet') || statusText.includes('offen') || statusText.includes('open') 
            ? 'open' 
            : 'closed'
        })
      }
    }

    // If no structured data found, try alternative patterns
    if (slopes.length === 0 && lifts.length === 0) {
      // Look for status indicators in different formats
      const generalPattern = /(?:class="[^"]*(?:open|closed|status)[^"]*"[^>]*>|<[^>]+>)\s*([^<]{3,50})\s*<.*?(?:geöffnet|geschlossen|open|closed)/gis
      
      while ((match = generalPattern.exec(html)) !== null) {
        const name = match[1].replace(/<[^>]+>/g, '').trim()
        const fullMatch = match[0].toLowerCase()
        
        if (name && name.length < 50 && !name.includes('http')) {
          const isOpen = fullMatch.includes('geöffnet') || fullMatch.includes('open')
          slopes.push({ name, status: isOpen ? 'open' : 'closed' })
        }
      }
    }

    const data: ScrapedData = {
      slopes,
      lifts,
      lastUpdated: new Date().toISOString(),
      source: 'kitzski.at'
    }

    // Save to Supabase database
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      // Count open/closed
      const slopesOpen = slopes.filter(s => s.status === 'open').length
      const liftsOpen = lifts.filter(l => l.status === 'open').length
      
      // Insert new status record
      await supabase
        .from('slope_status')
        .insert({
          resort: 'kitzbuehel',
          slopes_open: slopesOpen,
          slopes_total: slopes.length,
          lifts_open: liftsOpen,
          lifts_total: lifts.length,
          slopes: slopes,
          lifts: lifts,
          source_url: KITZSKI_URL,
          updated_at: new Date().toISOString()
        })
    }

    return new Response(
      JSON.stringify(data, null, 2),
      { 
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Scraping error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: error.message,
        slopes: [],
        lifts: [],
        lastUpdated: new Date().toISOString()
      }),
      { 
        status: 500,
        headers: { 
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json' 
        } 
      }
    )
  }
})

