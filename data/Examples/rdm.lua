-- Example:    {'battle 1 1', 'ja', 'Steal', 't', 'name/title'},  
-- Once you make changes type "//htb reload" in game 
-- If hotbar resets/duplicates or freaks out when switching characters. When you get back to main character. Type //lua unload xivhotbar2 and then //lua reload xihotbar

--KEYS{1,2,3,4,5}


xivhotbar_keybinds_job['Base'] = {
 

  
  -- -- Hotbar #1 (1-12)
  {'battle 1 1', 'ma', 'Cure', 'stpc', 'Cure'},
  {'battle 1 2', 'ma', 'Cure II', 'stpc', 'Cure2'},
  {'battle 1 3', 'ma', 'Cure III', 'stpc', 'Cure3'},
  {'battle 1 4', 'ma', 'Cure IV', 'stpc', 'Cure4'},
  {'battle 1 5', 'ma', 'Refresh', 'stpc', 'Refresh'},
  --{'battle 1 8', '', '', '', '', ''}, WS - Weapon Switching
  --{'battle 1 9', '', '', '', '', ''}, WS - Weapon Switching
  --{'battle 1 10', '', '', '', '', ''}, WS - Weapon Switching
  --{'battle 1 11', '', '', '', '', ''}, WS - Weapon Switching

  
  
  -- Hotbar #2 (ALT 1-12)
  --{'battle 2 3', 'ma', '', '', ''},
  --{'battle 2 4', 'ma', '', '', ''},
  --{'battle 2 5', 'ma', '', '', ''},
  --{'battle 2 6', 'ma', '', '', ''},
  --{'battle 2 9', '', '', '', ''},
  --{'battle 2 10', '', '', '', ''},
  --{'battle 2 11', '', '', '', ''},
  --{'battle 2 12', '', '', '', ''},


  -- Hotbar #3 (CTRL 1-12)

  --------------------------------------------------------------------------------------
  {'battle 3 2', 'ma', 'Paralyze II', 'stnpc', 'Para2'},
  {'battle 3 2', 'ma', 'Paralyze', 'stnpc', 'Para'},
  --------------------------------------------------------------------------------------
  {'battle 3 3', 'ma', 'Slow II', 'stnpc', 'Slow2'},
  {'battle 3 3', 'ma', 'Slow', 'stnpc', 'Slow'},
  --------------------------------------------------------------------------------------
  {'battle 3 4', 'ma', 'Silence', 'stnpc', 'Silence'},
  --------------------------------------------------------------------------------------
  {'battle 3 5', 'ma', 'Blind II', 'stnpc', 'Blind2'},
  {'battle 3 5', 'ma', 'Blind', 'stnpc', 'Blind'},
  --------------------------------------------------------------------------------------
  {'battle 3 6', 'ma', 'Gravity', 'stnpc', 'Gravity'},
  {'battle 3 7', 'ma', 'Bind', 'stnpc', 'Bind'},
  {'battle 3 8', 'ma', 'Sleep', 'stnpc', 'Sleep'},
  {'battle 3 9', 'ma', 'Sleep II', 'stnpc', 'Sleep2'},
  {'battle 3 10', 'ma', 'Dispel', 'stnpc', 'Dispel'},
  {'battle 3 12', 'ma', 'Diaga', 'stnpc', 'Diaga'},
  
  -- Hotbar #4 (SHIFT 1-12)
  {'battle 4 1', 'ma', 'Blink', 'me', 'Blink'},
  {'battle 4 2', 'ma', 'Stoneskin', 'me', 'Stnskin'},
  {'battle 4 4', 'ma', 'Aquaveil', 'me', 'Aquaveil'},
  {'battle 4 5', 'ma', 'Sneak', 'stpc', 'Sneak'},
  {'battle 4 6', 'ma', 'Invisible', 'stpc', 'Invis'},
  --------------------------------------------------------------------------------------
  {'battle 4 7', 'ma', 'Bio III', 't', 'Bio3'},
  {'battle 4 7', 'ma', 'Bio II', 't', 'Bio2'},
  {'battle 4 7', 'ma', 'Bio', 't', 'Bio'},
  --------------------------------------------------------------------------------------
  {'battle 4 8', 'ma', 'Poison II', 't', 'Poison2'},
  {'battle 4 8', 'ma', 'Poison', 't', 'Poison'},
  --------------------------------------------------------------------------------------
  {'battle 4 9', 'ja', 'Convert', 'me', 'Convert'},
  {'battle 4 10', 'ma', 'Raise', 'stpc', 'Raise'},
  --------------------------------------------------------------------------------------
  {'battle 4 11', 'ma', 'Protect III', 'stpc', 'Protect3'},
  {'battle 4 11', 'ma', 'Protect II', 'stpc', 'Protect2'},
  {'battle 4 11', 'ma', 'Protect', 'stpc', 'Protect'},
  --------------------------------------------------------------------------------------
  {'battle 4 12', 'ma', 'Shell III', 'stpc', 'Shell3'},
  {'battle 4 12', 'ma', 'Shell II', 'stpc', 'Shell2'},
  {'battle 4 12', 'ma', 'Shell', 'stpc', 'Shell'},
  
    -- Hotbar #5 (LETTERS)
  
  {'battle 5 7', 'ma', 'Stone', 't', 'Stone'},
  --------------------------------------------------------------------------------------
  {'battle 5 8', 'ma', 'Water', 't', 'Water'},
  --------------------------------------------------------------------------------------
  {'battle 5 9', 'ma', 'Aero', 't', 'Aero'},
  --------------------------------------------------------------------------------------
  {'battle 5 10', 'ma', 'Fire', 't', 'Fire'},
  --------------------------------------------------------------------------------------
  {'battle 5 11', 'ma', 'Blizzard', 't', 'Blizz'},
  --------------------------------------------------------------------------------------
  {'battle 5 12', 'ma', 'Thunder', 't', 'Thun'},
  --------------------------------------------------------------------------------------

   -- Hotbar #6 (Shift + LETTERS)
  
  {'battle 6 1', 'ma', 'Barstonra', 'stpc', 'Barston','Barstonra'},
  {'battle 6 2', 'ma', 'Barwatera', 'stpc', 'Barwater','Barwatera'},
  {'battle 6 3', 'ma', 'Baraera', 'stpc', 'Baraera', 'Baraera'},
  {'battle 6 4', 'ma', 'Barfira', 'stpc', 'Barfira', 'Barfira'},
  {'battle 6 5', 'ma', 'Barblizzara', 'stpc', 'Barblizz','Barblizzara'},
  {'battle 6 6', 'ma', 'Barthundra', 'stpc', 'Barthun', 'Barthundra'},
  {'battle 6 7', 'ma', 'Enstone', 'me', 'Enstone'},
  {'battle 6 8', 'ma', 'Enwater', 'me', 'Enwater'},
  {'battle 6 9', 'ma', 'Enaero', 'me', 'Enaero'},
  {'battle 6 10', 'ma', 'Enfire', 'me', 'Enfire'},
  {'battle 6 11', 'ma', 'Enblizzard', 'me', 'Enblizz'},
  {'battle 6 12', 'ma', 'Enthunder', 'me', 'Enthun'},

	{'b 3 1', 'ma', "Dia II", 't', "DiII"},
	{'b 1 11', 'ws', "Vorpal Blade", 't', "VorpBl"},
	{'b 3 11', 'ma', "Dia III", 't', "DiII"},
	{'b 2 4', 'ma', "Waterga II", 't', "WatrII"},
	{'b 2 3', 'ma', "Stonega II", 't', "StonII"},
	{'b 7 8', 'ma', "Valaineral", 'me', "Valn"},
	{'b 7 9', 'ma', "Yoran-Oran (UC)", 'me', "Yorn-O"},
	{'b 7 1', 'ma', "Poisonga", 't', "Posn"},
	{'b 2 5', 'ma', "Aeroga II", 't', "AergII"},
	{'b 2 6', 'ma', "Firaga", 't', "Firg"},
	{'b 2 7', 'ma', "Blizzaga", 't', "Bliz"},
	{'b 2 9', 'ja', "Parsimony", 'me', "Pars"},
	{'b 2 1', 'ma', "Frazzle II", 't', "FrazII"},
	{'b 2 11', 'ja', "Celerity", 'me', "Celr"},
	{'b 4 3', 'ma', "Phalanx II", 'stpc', "PhalII"},
	{'b 7 6', 'ja', "Composure", 'me', "Comp"},
	{'b 7 7', 'ja', "Chainspell", 'me', "Chan"},
	{'b 1 7', 'ma', "Regen II", 'stpc', "RegnII"},
	{'b 4 12', 'ma', "Shell IV", 'stpc', "ShelIV"},
	{'b 4 11', 'ma', "Protect IV", 'stpc', "ProtIV"},
	{'b 2 12', 'ja', "Alacrity", 'me', "Alac"},
	{'b 7 5', 'ma', "Inundation", 't', "Inun"},
	{'b 7 4', 'ma', "Addle", 't', "Addl"},
	{'b 7 3', 'ma', "Poison II", 't', "PosnII"},
	{'b 7 2', 'ja', "Saboteur", 'me', "Sabt"},
	{'b 5 5', 'ma', "Blizzard IV", 't', "BlizIV"},
	{'b 5 3', 'ma', "Aero IV", 't', "AerIV"},
	{'b 5 2', 'ma', "Water IV", 't', "WatrIV"},
	{'b 5 1', 'ma', "Stone IV", 't', "StonIV"},
	{'b 5 4', 'ma', "Fire IV", 't', "FirIV"},
	{'b 5 6', 'ma', "Thunder IV", 't', "ThunIV"},
	{'b 5 7', 'ma', "Stone III", 't', "StonII"},
	{'b 5 12', 'ma', "Thunder III", 't', "ThunII"},
	{'b 5 11', 'ma', "Blizzard III", 't', "BlizII"},
	{'b 5 10', 'ma', "Fire III", 't', "FirII"},
	{'b 5 9', 'ma', "Aero III", 't', "AerII"},
	{'b 5 8', 'ma', "Water III", 't', "WatrII"},
	{'b 7 11', 'ma', "Shantotto II", 'me', "ShanII"},
	{'b 7 10', 'ma', "Qultada", 'me', "Qult"},
	{'b 2 2', 'ma', "Distract II", 't', "DistII"},
	{'b 2 10', 'ja', "Manifestation", 'me', "Manf"},
	{'b 1 10', 'ws', "Circle Blade", 't', "CircBl"},
	{'b 1 9', 'ws', "Savage Blade", 't', "SavgBl"},
	{'b 7 12', 'ma', "Zeid II", 'me', "ZedII"},
	{'b 1 8', 'ma', "Flurry II", 'stpc', "FlurII"},
	{'b 1 6', 'ma', "Haste II", 'stpc', "HastII"},
	{'b 2 8', 'ma', "Thundaga", 't', "Thun"},
 }


xivhotbar_keybinds_job['WHM'] = {
 
  
  -- Hotbar #2 (ALT 1-0)
  {'battle 2 1', 'ma', 'Poisona', 'stpc', 'Poisona'},
  {'battle 2 2', 'ma', 'Paralyna', 'stpc', 'Paralyna'},
  {'battle 2 3', 'ma', 'Blindna', 'stpc', 'Blindna'},
  {'battle 2 4', 'ma', 'Silena', 'stpc', 'Silena'},
  {'battle 2 5', 'ma', 'Cursna', 'stpc', 'Cursna'},
  {'battle 2 6', 'ma', 'Viruna', 'stpc', 'Viruna'},
  {'battle 2 7', 'ma', 'Erase', 'stpc', 'Erase'},
  {'battle 2 8', 'ja', 'Divine Seal', 'me', 'Div.Seal'},
  --------------------------------------------------------------------------------------
  {'battle 2 9', 'ma', 'Curaga', 'stpc', 'Curaga'},
  --------------------------------------------------------------------------------------
  {'battle 2 10', 'ma', 'Reraise', 'me', 'Reraise'},
  --------------------------------------------------------------------------------------
  {'battle 2 11', 'ma', 'Protectra II', 'stpc', 'Protra2'},
  {'battle 2 11', 'ma', 'Protectra', 'stpc', 'Protra'},
  --------------------------------------------------------------------------------------
  {'battle 2 12', 'ma', 'Shellra II', 'stpc', 'Shellra2'},
  {'battle 2 12', 'ma', 'Shellra', 'stpc', 'Shellra'},
  --------------------------------------------------------------------------------------

	{'b 3 1', 'ma', "Dia II", 't', "DiII"},
	{'b 1 11', 'ws', "Vorpal Blade", 't', "VorpBl"},
}

xivhotbar_keybinds_job['NIN'] = {
 
  -- Hotbar #1 (1-0)

  -- Hotbar #2 (ALT 1-0)
  {'battle 2 1', 'ma', 'Utsusemi: Ni', 'me', 'Ni'},
  {'battle 2 2', 'ma', 'Utsusemi: Ichi', 'me', 'Ichi'},



  

  -- Hotbar #3 (CTRL 1-0)
  
  
  -- Hotbar #4 (SHIFT 1-0)

}



xivhotbar_keybinds_job['THF'] = {
 
  -- Hotbar #1 (1-0)

  -- Hotbar #2 (ALT 1-0)
    {'battle 2 1', 'ja', 'Sneak Attack', 'me', 'Sneak'},
    {'battle 2 2', 'ja', 'Trick Attack', 'me', 'Trick'},
    {'battle 2 3', 'ja', 'Steal', 't', 'Steal'},
    {'battle 2 4', 'input', '/ws Cyclone <t>', '', 'cyc', 'wsaoe'},
    {'battle 2 5', 'ja', 'Flee', 'me', 'Flee'},


  

  -- Hotbar #3 (CTRL 1-0)
  
  
  -- Hotbar #4 (SHIFT 1-0)

}
xivhotbar_keybinds_job['Sword'] = {
 
  -- Hotbar #1 (1-0)


}
xivhotbar_keybinds_job['Dagger'] = {
 
  -- Hotbar #1 (1-0)
  {'battle 1 9', 'ws', 'Wasp Sting', 't', 'Wasp'},



}
xivhotbar_keybinds_job['BLM'] = {



}

return xivhotbar_keybinds_job

