
BEGIN	{
	  inrecord = 0;
	  target = ZZ;
	}

NF == 10 {
      if ($2 == "start" && $3 == "query")
	  {
	    if ($4 == target)
	  	  inrecord = 1;
	    else 
		  inrecord = 0;
	  }
      else {
        if ($2 == "end" && $3 == "query")
		  inrecord = 0;
		else {
	      if (inrecord)
		    print $0
		}
	  }

	}

    {
	  if ($1 != "--" && inrecord == 1)
	    print $0	  
	}
